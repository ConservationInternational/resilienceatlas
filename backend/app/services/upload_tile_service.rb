require "net/http"
require "uri"

class UploadTileService
  def initialize(di)
    @di = di
  end

  def tile(z, x, y)
    limit = 2**z
    raise ArgumentError, "Invalid tile coordinates" unless z.between?(0, 22) && x.between?(0, limit - 1) && y.between?(0, limit - 1)
    if @di.type_vector?
      get("/ra_vector_tile/#{z}/#{x}/#{y}", table: @di.metadata.fetch("table"))
    else
      body = JSON.parse(UploadLayerConfiguration.new(@di).attributes.fetch(:layer_config)).fetch("body")
      query = body.slice("bidx", "rescale", "nodata", "colormap_name", "resampling_method").merge("url" => body.fetch("source"))
      query["bidx"] = body.fetch("bidx", 1).to_s.split(",")
      query["colormap"] = body["colormap"].to_json if body["colormap"]
      get("/tiles/WebMercatorQuad/#{z}/#{x}/#{y}.png", query)
    end
  end

  def point(lon, lat)
    raise ArgumentError, "Invalid coordinates" unless lon.finite? && lat.finite? && lon.between?(-180, 180) && lat.between?(-90, 90)
    raise ArgumentError, "Point queries require a raster" unless @di.type_cog?
    get("/point/#{lon}/#{lat}", url: @di.metadata.fetch("source"), bidx: @di.options.fetch("bidx", 1).to_s.split(","))
  end

  def verify!
    if @di.type_cog?
      info = JSON.parse(get("/info", url: @di.metadata.fetch("source")).body)
      raise IOError, "TiTiler returned no bands" if info["band_metadata"].blank? && info["count"].to_i.zero?
    end
    bounds = @di.metadata.fetch("bounds")
    lon = (bounds[0] + bounds[2]) / 2.0
    lat = ((bounds[1] + bounds[3]) / 2.0).clamp(-85.0, 85.0)
    z = 2
    x = ((lon + 180) / 360 * (2**z)).floor.clamp(0, 2**z - 1)
    rad = lat * Math::PI / 180
    y = ((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math::PI) / 2 * (2**z)).floor.clamp(0, 2**z - 1)
    response = tile(z, x, y)
    if @di.type_cog? && !response.body.start_with?("\x89PNG".b)
      raise IOError, "TiTiler did not return a PNG tile"
    end
    true
  end

  private

  def get(path, query)
    base = if @di.type_vector?
      ENV.fetch("MARTIN_URL", "http://martin:3000")
    else
      ENV.fetch("TITILER_URL") do
        (ENV.fetch("FRONTEND_URL", "").include?("staging") || !Rails.env.production?) ?
          "https://staging.titiler.resilienceatlas.org" : "https://titiler.resilienceatlas.org"
      end
    end
    uri = URI("#{base.delete_suffix("/")}#{path}")
    uri.query = URI.encode_www_form(query)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
      open_timeout: 10, read_timeout: 60) { |http| http.get(uri.request_uri) }
    raise IOError, "Tile service returned HTTP #{response.code}: #{response.body.to_s.first(300)}" unless response.is_a?(Net::HTTPSuccess)
    response
  end
end
