require "json"
require "pathname"
require "fileutils"
require "securerandom"
require "timeout"

# Prepares an immutable raster artifact; publishing it to a layer is a separate step.
class RasterUploadProcessor
  class Error < StandardError; end

  def initialize(data_import, work_dir:, storage:)
    @data_import = data_import
    @work_dir = Pathname.new(work_dir).expand_path
    @storage = storage
  end

  def call(local_path)
    raise Error, "Expected a COG import" unless @data_import.import_type == "cog"

    @deadline = monotonic_time + Integer(ENV.fetch("UPLOAD_PROCESSING_TIMEOUT_SECONDS", "1800"))
    @warnings = []
    @options = (@data_import.options || {}).transform_keys(&:to_s)
    kind = @options.fetch("raster_kind", "continuous")
    raise Error, "Invalid raster_kind" unless %w[categorical continuous rgb].include?(kind)

    path = Pathname.new(local_path).expand_path.to_s
    raise Error, "Raster file is missing or empty" unless File.file?(path) && File.size(path).positive?

    FileUtils.mkdir_p(@work_dir)
    input = inspect_raster(path)
    validate_raster!(input)
    if input.dig("coordinateSystem", "wkt").to_s.empty?
      crs = @options["source_crs"].to_s
      raise Error, "Missing CRS: supply an explicit EPSG source_crs" unless crs.match?(/\AEPSG:[1-9]\d*\z/)

      assigned_path = @work_dir.join("assigned-#{SecureRandom.uuid}.vrt").to_s
      command("gdal_translate", "-of", "VRT", "-a_srs", crs, path, assigned_path)
      path = assigned_path
      input = inspect_raster(path)
      validate_raster!(input, driver: "VRT")
      @warnings << "Missing source CRS was assigned #{crs}; pixel coordinates were not changed."
    end
    raise Error, "Raster CRS could not be resolved" if input.dig("coordinateSystem", "wkt").to_s.empty?

    bounds = geographic_bounds(input)
    @warnings << "One or more bands have no explicit nodata value; existing masks are preserved." if input["bands"].any? { |band| !band.key?("noDataValue") }
    palette = input["bands"].any? { |band| band.key?("colorTable") }
    resampling = (kind == "categorical" || palette) ? "NEAREST" : "AVERAGE"
    unless @options.key?("raster_kind")
      @warnings << "raster_kind was not supplied; treating the raster as #{kind} with #{resampling.downcase} overviews."
    end
    @warnings << "Palette data uses nearest-neighbor overviews to preserve categories." if palette && kind != "categorical"
    uuid = SecureRandom.uuid
    output = @work_dir.join("#{uuid}.tif").to_s
    command(
      "gdal_translate", "-of", "COG",
      "-co", "COMPRESS=DEFLATE", "-co", "BIGTIFF=IF_SAFER",
      "-co", "NUM_THREADS=2", "-co", "OVERVIEWS=IGNORE_EXISTING",
      "-co", "RESAMPLING=#{resampling}", path, output
    )
    result = inspect_raster(output)
    validate_output!(input, result)
    raise Error, "COG output is missing or empty" unless File.file?(output) && File.size(output).positive?

    key = "cogs/imports/#{@data_import.id}/#{uuid}.tif"
    @storage.upload_file(output, key, content_type: "image/tiff")
    head = @storage.head(key)
    length = if head.respond_to?(:content_length)
      head.content_length
    elsif head.is_a?(Hash)
      head[:content_length] || head["content_length"] || head["ContentLength"]
    end
    raise Error, "Uploaded COG size could not be verified" unless length.to_i == File.size(output)

    {
      "source" => "s3://#{@storage.bucket}/#{key}",
      "bounds" => bounds,
      "bands" => result["bands"],
      "driver" => result["driverShortName"],
      "crs" => result.dig("coordinateSystem", "wkt"),
      "warnings" => @warnings,
      "output_key" => key,
      "width" => result["size"][0],
      "height" => result["size"][1],
      "raster_kind" => kind
    }
  rescue JSON::ParserError => e
    raise Error, "Invalid gdalinfo JSON: #{e.message}"
  end

  private

  def inspect_raster(path)
    JSON.parse(command("gdalinfo", "-json", "-stats", path))
  end

  def validate_raster!(info, driver: "GTiff")
    raise Error, "Input must be a GeoTIFF" unless info["driverShortName"] == driver

    size = info["size"]
    unless size.is_a?(Array) && size.length == 2 && size.all? { |n| n.is_a?(Integer) && n.positive? }
      raise Error, "Raster has empty or invalid dimensions"
    end
    transform = info["geoTransform"]
    unless transform.is_a?(Array) && transform.length == 6 &&
        transform.all? { |n| n.is_a?(Numeric) && n.finite? } &&
        (transform[1] * transform[5] - transform[2] * transform[4]) != 0
      raise Error, "Raster has no usable affine georeferencing"
    end
    bands = info["bands"]
    raise Error, "Raster contains no bands" unless bands.is_a?(Array) && !bands.empty?

    bands.each do |band|
      raise Error, "Raster band has no data type" if band["type"].to_s.empty?

      if band.key?("noDataValue") && !band["noDataValue"].is_a?(Numeric) &&
          !band["noDataValue"].to_s.match?(/\A[+-]?(nan|inf(inity)?)\z/i)
        raise Error, "Raster has an invalid nodata value"
      end
      valid_percent = band.dig("metadata", "", "STATISTICS_VALID_PERCENT")
      raise Error, "Raster band contains only nodata or masked pixels" if valid_percent && Float(valid_percent) <= 0
    end
  end

  def geographic_bounds(info)
    points = coordinate_pairs(info.dig("wgs84Extent", "coordinates"))
    unless points.length >= 4 && points.all? { |x, y| x.finite? && y.finite? && x.between?(-180, 180) && y.between?(-90, 90) }
      raise Error, "Raster has no valid WGS84 bounds"
    end
    west, east = points.map(&:first).minmax
    south, north = points.map(&:last).minmax
    raise Error, "Raster has empty WGS84 bounds" unless west < east && south < north

    [west, south, east, north]
  end

  def coordinate_pairs(coordinates)
    return [] unless coordinates.is_a?(Array)
    return [coordinates.first(2)] if coordinates.length >= 2 && coordinates.first(2).all? { |n| n.is_a?(Numeric) }

    coordinates.flat_map { |child| coordinate_pairs(child) }
  end

  def validate_output!(input, result)
    validate_raster!(result)
    unless result.dig("metadata", "IMAGE_STRUCTURE", "LAYOUT") == "COG"
      raise Error, "GDAL output does not have COG layout"
    end
    unless result["size"] == input["size"] && result["bands"].length == input["bands"].length
      raise Error, "COG conversion changed raster dimensions or band count"
    end
    unless result["geoTransform"] == input["geoTransform"] && same_crs?(input, result)
      raise Error, "COG conversion changed raster georeferencing"
    end
    input["bands"].zip(result["bands"]).each do |original, converted|
      %w[type noDataValue scale offset colorInterpretation colorTable].each do |field|
        unless original[field] == converted[field]
          raise Error, "COG conversion changed band #{field}"
        end
      end
      original_mask = original.dig("mask", "flags")
      if original_mask && original_mask.sort != Array(converted.dig("mask", "flags")).sort
        raise Error, "COG conversion changed raster mask"
      end
    end
  end

  def same_crs?(input, result)
    original = input.fetch("coordinateSystem")
    converted = result.fetch("coordinateSystem")
    return true if original == converted

    # GeoTIFF may canonicalize an EPSG datum to its newer ensemble WKT.
    authority = /ID\["EPSG",\s*(\d+)\]\]\s*\z/
    original_code = original.fetch("wkt").match(authority)&.captures&.first
    converted_code = converted.fetch("wkt").match(authority)&.captures&.first
    original_code && original_code == converted_code &&
      original["dataAxisToSRSAxisMapping"] == converted["dataAxisToSRSAxisMapping"]
  end

  def command(*argv)
    remaining = @deadline - monotonic_time
    raise Error, "Raster processing time budget exceeded" unless remaining.positive?

    Timeout.timeout(remaining) do
      UploadCommand.run(
        *argv,
        env: {"GDAL_CACHEMAX" => "128", "GDAL_NUM_THREADS" => "2", "GDAL_TIFF_INTERNAL_MASK" => "YES"}
      )
    end
  rescue Timeout::Error
    raise Error, "Raster processing time budget exceeded"
  end

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
