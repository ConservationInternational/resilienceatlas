require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "zip"

class VectorUploadProcessor
  TARGET_SCHEMA = "ra_vector"
  SUPPORTED_EXTENSIONS = %w[.gpkg .geojson .json .zip .shp].freeze
  MAX_ARCHIVE_ENTRIES = 10_000
  MAX_ARCHIVE_ENTRY_BYTES = 1.gigabyte
  MAX_ARCHIVE_BYTES = 2.gigabytes

  def initialize(data_import, work_dir:, storage:)
    @data_import = data_import
    @work_dir = Pathname(work_dir)
    @storage = storage
  end

  def call(local_path)
    source_path = Pathname(local_path)
    validate_source!(source_path)
    source_path = extract_shapefile_archive(source_path) if source_path.extname.downcase == ".zip"

    discovered = discover_layers(source_path)
    spatial_layers = discovered.select { |layer| spatial_layer?(layer) }
    raise ArgumentError, "The uploaded dataset has no spatial layers" if spatial_layers.empty?

    selection = selected_layer(spatial_layers)
    options = import_options
    source_crs = validate_epsg!(options["source_crs"]) if options["source_crs"].present?
    if source_crs.blank? && !selection[:crs_present]
      raise UploadSelectionRequired.new(
        "Choose a source CRS before importing this dataset",
        selection_metadata(spatial_layers, source_crs_required: true)
      )
    end
    source_crs ||= selected_source_crs(selection)
    persisted_options = options.merge("sublayer" => selection.fetch(:name))
    persisted_options["source_crs"] = source_crs if source_crs.present?
    persist_options!(persisted_options)

    table = "imported_#{@data_import.id}_#{SecureRandom.hex(8)}"
    conn = ActiveRecord::Base.connection
    ensure_table_absent!(conn, table)
    import_layer(
      source_path, selection.fetch(:name), table, source_crs, selection.fetch(:epsg), selection.fetch(:crs_present)
    )

    repairs = VectorGeometryRepair.repair_table!(
      conn, schema: TARGET_SCHEMA, table: table, batch_size: 500
    )
    create_spatial_indexes!(conn, table)
    conn.execute(
      "ANALYZE #{conn.quote_table_name(TARGET_SCHEMA)}.#{conn.quote_table_name(table)}"
    )

    imported_metadata = verify_import!(conn, table)
    interaction_config = LayerInteractionConfigBuilder.for_martin(table, conn, TARGET_SCHEMA)
    warnings = []
    warnings << "#{repairs[:skipped]} geometries could not be repaired" if repairs[:skipped].to_i.positive?

    {
      "table" => table,
      "bounds" => imported_metadata.fetch(:bounds),
      "rows" => imported_metadata.fetch(:rows),
      "geometry_type" => imported_metadata.fetch(:geometry_type),
      "fields" => imported_metadata.fetch(:fields),
      "warnings" => warnings,
      "interaction_config" => interaction_config,
      "sublayers" => spatial_layers.map { |layer| layer.fetch(:name) }
    }
  end

  private

  def validate_source!(path)
    raise ArgumentError, "Unsupported vector upload type" unless SUPPORTED_EXTENSIONS.include?(path.extname.downcase)
    raise ArgumentError, "Uploaded vector file does not exist" unless path.file?
  end

  def discover_layers(path)
    listing = UploadCommand.run("ogrinfo", "-ro", path.to_s)
    names = listing.lines.filter_map do |line|
      match = line.match(/^\s*\d+:\s*(.*?)\s+\(([^()]*)\)\s*$/)
      match && [match[1], match[2]]
    end
    raise ArgumentError, "GDAL could not discover any layers in the uploaded dataset" if names.empty?

    names.map do |name, listed_geometry|
      details = UploadCommand.run("ogrinfo", "-ro", "-so", path.to_s, name)
      parse_layer_details(name, listed_geometry, details)
    end
  end

  def parse_layer_details(name, listed_geometry, details)
    geometry = details[/^\s*Geometry:\s*(.+?)\s*$/i, 1] || listed_geometry
    fields = details.lines.filter_map do |line|
      match = line.match(
        /^\s+([^:]+):\s+(?:Integer|Integer64|Real|String|Date|Time|DateTime|Binary|IntegerList|Integer64List|RealList|StringList)(?:\([^)]*\))?(?:\s|$)/
      )
      match && match[1].strip
    end
    wkt = details[/^\s*Layer SRS WKT:\s*\n(.*)/m, 1].to_s
    {
      name: name,
      geometry_type: geometry.to_s.strip,
      epsg: root_epsg_code(wkt),
      crs_present: wkt.match?(/\A\s*[A-Z][A-Z0-9_]*\s*\[/),
      fields: fields,
      feature_count: details[/^\s*Feature Count:\s*(\d+)\s*$/i, 1]&.to_i
    }
  end

  def root_epsg_code(wkt)
    return unless wkt.match?(/\A\s*[A-Z][A-Z0-9_]*\s*\[/)

    epsg_pattern = /(?:AUTHORITY|ID)\["EPSG",\s*"?(\d+)"?\]/i
    cursor = 0
    depth = 0
    epsg = nil
    while (match = epsg_pattern.match(wkt, cursor))
      wkt[cursor...match.begin(0)].each_char do |character|
        depth += 1 if character == "["
        depth -= 1 if character == "]"
      end
      epsg = match[1].to_i if depth == 1
      cursor = match.end(0)
    end
    epsg
  end

  def spatial_layer?(layer)
    !layer[:geometry_type].match?(/\A(?:none|unknown|)\z/i)
  end

  def selected_layer(spatial_layers)
    options = import_options
    selected_name = options["sublayer"]
    if spatial_layers.length > 1 && selected_name.blank?
      raise UploadSelectionRequired.new(
        "Choose a spatial layer to import",
        selection_metadata(spatial_layers)
      )
    end

    layer = if selected_name.present?
      spatial_layers.find { |candidate| candidate[:name] == selected_name }
    else
      spatial_layers.first
    end
    raise ArgumentError, "Selected sublayer is not a spatial layer in the uploaded dataset" unless layer

    layer
  end

  def selection_metadata(spatial_layers, source_crs_required: false)
    {
      "sublayers" => spatial_layers.map { |layer| layer.fetch(:name) },
      "source_crs_required" => source_crs_required
    }
  end

  def selected_source_crs(layer)
    layer[:epsg] && "EPSG:#{layer[:epsg]}"
  end

  def validate_epsg!(value)
    match = value.to_s.match(/\AEPSG:(\d+)\z/i)
    raise ArgumentError, "Source CRS must be an explicit EPSG code" unless match

    "EPSG:#{match[1]}"
  end

  def import_options
    options = @data_import.respond_to?(:options) ? @data_import.options : {}
    options = JSON.parse(options) if options.is_a?(String) && options.present?
    options.is_a?(Hash) ? options.stringify_keys : {}
  rescue JSON::ParserError
    raise ArgumentError, "Data import options must be a JSON object"
  end

  def persist_options!(options)
    return unless @data_import.respond_to?(:options=)

    @data_import.options = options
    @data_import.save! if @data_import.respond_to?(:save!)
  end

  def extract_shapefile_archive(path)
    raise ArgumentError, "ZIP upload exceeds the allowed compressed size" if path.size > MAX_ARCHIVE_BYTES

    extraction_dir = @work_dir.join("vector_upload_#{SecureRandom.hex(8)}")
    FileUtils.mkdir_p(extraction_dir)

    Zip::File.open(path.to_s) do |archive|
      validate_archive!(archive)
      total_size = 0
      archive.each do |entry|
        next if entry.directory?

        relative = safe_archive_path!(entry)
        destination = extraction_dir.join(relative)
        FileUtils.mkdir_p(destination.dirname)
        total_size += extract_archive_entry!(entry, destination, MAX_ARCHIVE_BYTES - total_size)
      end
    end

    shapefiles = Dir.glob(extraction_dir.join("**", "*.shp").to_s, File::FNM_CASEFOLD)
    raise ArgumentError, "ZIP upload must contain a shapefile" if shapefiles.empty?
    raise ArgumentError, "ZIP upload must contain exactly one shapefile" if shapefiles.length > 1

    shapefile = Pathname(shapefiles.first)
    %w[.shx .dbf].each do |extension|
      companion_name = "#{shapefile.basename(shapefile.extname)}#{extension}"
      found = Dir.children(shapefile.dirname).any? { |entry| entry.casecmp?(companion_name) }
      raise ArgumentError, "ZIP shapefile is missing #{extension}" unless found
    end
    shapefile
  rescue Zip::Error => e
    raise ArgumentError, "Invalid ZIP vector upload: #{e.message}"
  end

  def validate_archive!(archive)
    raise ArgumentError, "ZIP upload contains too many entries" if archive.size > MAX_ARCHIVE_ENTRIES

    total_size = 0
    archive.each do |entry|
      raise ArgumentError, "ZIP upload contains an oversized file" if entry.size > MAX_ARCHIVE_ENTRY_BYTES

      total_size += entry.size
      raise ArgumentError, "ZIP upload expands beyond the allowed size" if total_size > MAX_ARCHIVE_BYTES
      safe_archive_path!(entry)
      mode = entry.unix_perms.to_i
      raise ArgumentError, "ZIP upload cannot contain symbolic links" if (mode & 0o170000) == 0o120000
    end
  end

  def extract_archive_entry!(entry, destination, remaining_archive_bytes)
    bytes_written = 0
    File.open(destination, "wb") do |file|
      stream = entry.get_input_stream
      begin
        while (chunk = stream.read(64 * 1024))
          bytes_written += chunk.bytesize
          raise ArgumentError, "ZIP upload contains an oversized file" if bytes_written > MAX_ARCHIVE_ENTRY_BYTES
          if bytes_written > remaining_archive_bytes
            raise ArgumentError, "ZIP upload expands beyond the allowed size"
          end

          file.write(chunk)
        end
      ensure
        stream.close
      end
    end
    bytes_written
  end

  def safe_archive_path!(entry)
    name = entry.name
    raise ArgumentError, "ZIP upload contains an invalid path" if name.include?("\0") || name.include?("\\")
    raise ArgumentError, "ZIP upload contains an absolute path" if name.start_with?("/") || name.match?(/\A[A-Za-z]:/)

    parts = name.sub(%r{/\z}, "").split("/")
    raise ArgumentError, "ZIP upload contains a path traversal" if parts.any? { |part| part == ".." || part == "." }
    raise ArgumentError, "ZIP upload contains an invalid path" if parts.empty? || parts.any?(&:empty?)
    raise ArgumentError, "ZIP upload contains a path that is too deep" if parts.length > 32
    raise ArgumentError, "ZIP upload contains an oversized path component" if parts.any? { |part| part.bytesize > 255 }

    Pathname(parts.join("/"))
  end

  def import_layer(path, layer_name, table, source_crs, detected_epsg, crs_present)
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    env = {"PGPASSWORD" => config[:password].to_s}
    conn_string = [
      "PG:host=#{safe_connection_value(config[:host] || "localhost")}",
      "port=#{config[:port] || 5432}",
      "dbname=#{safe_connection_value(config[:database])}",
      "user=#{safe_connection_value(config[:username])}"
    ].join(" ")
    argv = [
      "ogr2ogr", "-f", "PostgreSQL", conn_string, path.to_s, layer_name,
      "-nln", "#{TARGET_SCHEMA}.#{table}",
      "-nlt", "PROMOTE_TO_MULTI",
      "-t_srs", "EPSG:4326",
      "-lco", "GEOMETRY_NAME=geom",
      "-lco", "SPATIAL_INDEX=GIST"
    ]
    if source_crs.present? && (detected_epsg.nil? || source_crs != "EPSG:#{detected_epsg}") && !crs_present
      argv.concat(["-s_srs", source_crs])
    end
    UploadCommand.run(*argv, env: env)
  end

  def safe_connection_value(value)
    value.to_s.gsub(/[^a-zA-Z0-9._-]/, "")
  end

  def ensure_table_absent!(conn, table)
    exists = conn.select_value(
      "SELECT to_regclass(#{conn.quote("#{TARGET_SCHEMA}.#{table}")}) IS NOT NULL"
    )
    raise ArgumentError, "Generated vector table already exists" if exists
  end

  def create_spatial_indexes!(conn, table)
    geometry_columns(conn, table).each do |column|
      index = "idx_#{table}_#{column}"[0, 63]
      conn.execute(
        "CREATE INDEX IF NOT EXISTS #{conn.quote_table_name(index)} " \
        "ON #{quoted_table(conn, table)} USING GIST (#{conn.quote_column_name(column)})"
      )
    end
  end

  def geometry_columns(conn, table)
    conn.exec_query(
      "SELECT f_geometry_column FROM geometry_columns " \
      "WHERE f_table_schema = #{conn.quote(TARGET_SCHEMA)} AND f_table_name = #{conn.quote(table)}"
    ).map { |row| row["f_geometry_column"] }
  end

  def verify_import!(conn, table)
    geometry = geometry_columns(conn, table).first
    raise ArgumentError, "Imported vector table has no geometry column" unless geometry

    quoted_geometry = conn.quote_column_name(geometry)
    quoted = quoted_table(conn, table)
    row = conn.select_one(
      "SELECT COUNT(*) AS rows, COUNT(#{quoted_geometry}) AS geometry_rows, " \
      "(SELECT ST_GeometryType(#{quoted_geometry}) FROM #{quoted} " \
      "WHERE #{quoted_geometry} IS NOT NULL LIMIT 1) AS geometry_type, " \
      "ST_Extent(#{quoted_geometry})::text AS bounds " \
      "FROM #{quoted}"
    )
    rows = row["rows"].to_i
    raise ArgumentError, "Imported vector table contains no rows" if rows.zero?
    raise ArgumentError, "Imported vector table contains no usable geometries" if row["geometry_rows"].to_i.zero?

    bounds = parse_bounds(row["bounds"])
    verify_mvt_query!(conn, table, geometry)
    {
      rows: rows,
      geometry_type: row["geometry_type"].to_s.sub(/\AST_/, ""),
      bounds: bounds,
      fields: field_names(conn, table, geometry)
    }
  end

  def parse_bounds(value)
    match = value.to_s.match(/\ABOX\(([-+\deE.]+)\s+([-+\deE.]+),([-+\deE.]+)\s+([-+\deE.]+)\)\z/)
    raise ArgumentError, "Imported vector table has invalid bounds" unless match

    match.captures.map(&:to_f)
  end

  def verify_mvt_query!(conn, table, geometry)
    quoted = quoted_table(conn, table)
    quoted_geometry = conn.quote_column_name(geometry)
    tile = "ST_TileEnvelope(0, 0, 0)"
    sql = <<~SQL.squish
      SELECT octet_length(ST_AsMVT(tile_rows, 'upload', 4096, 'mvtgeom'))
      FROM (
        SELECT ST_AsMVTGeom(ST_Transform(#{quoted_geometry}, 3857), #{tile}, 4096, 256, true) AS mvtgeom
        FROM #{quoted}
        WHERE #{quoted_geometry} IS NOT NULL
      ) tile_rows
      WHERE mvtgeom IS NOT NULL
    SQL
    bytes = conn.select_value(sql).to_i
    raise ArgumentError, "Imported vector table cannot produce a usable MVT tile" if bytes.zero?
  end

  def field_names(conn, table, geometry)
    conn.exec_query(
      "SELECT column_name FROM information_schema.columns " \
      "WHERE table_schema = #{conn.quote(TARGET_SCHEMA)} " \
      "AND table_name = #{conn.quote(table)} ORDER BY ordinal_position"
    ).map { |row| row["column_name"] }.reject do |name|
      name == geometry || name == "ogc_fid"
    end
  end

  def quoted_table(conn, table)
    "#{conn.quote_table_name(TARGET_SCHEMA)}.#{conn.quote_table_name(table)}"
  end
end
