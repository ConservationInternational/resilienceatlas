require "net/http"
require "uri"
require "cgi"

class TileRendererService
  Result = Struct.new(:status, :body, :content_type, :error, keyword_init: true) do
    def success?
      status.to_i == 200 && body.is_a?(String) && body.present?
    end
  end

  COORDINATE_MAX_ZOOM = 22
  COG_ALLOWED_HOSTS = [
    /\As3\.amazonaws\.com\z/,
    /\A[\w-]+\.s3\.amazonaws\.com\z/,
    /\A[\w-]+\.s3\.[\w-]+\.amazonaws\.com\z/,
    /\Astorage\.googleapis\.com\z/,
    /\A[\w.-]+\.storage\.googleapis\.com\z/,
    /\Atitiler\.resilienceatlas\.org\z/,
    /\A[\w-]+\.titiler\.resilienceatlas\.org\z/
  ].freeze
  TITILER_ALLOWED_HOSTS = [
    /\Atitiler\.resilienceatlas\.org\z/,
    /\A[\w-]+\.titiler\.resilienceatlas\.org\z/
  ].freeze
  RESAMPLING_METHODS = %w[nearest bilinear cubic cubic_spline lanczos average mode].freeze
  COG_VARIANT_KEYS = %w[bidx colormap colormap_name nodata rescale resampling_method feature].freeze

  def self.valid_coordinates?(z, x, y)
    z && x && y && z.between?(0, COORDINATE_MAX_ZOOM) &&
      x.between?(0, 2**z - 1) && y.between?(0, 2**z - 1)
  end

  def self.render(layer, z:, x:, y:, params: {})
    return failure(400, "Invalid tile coordinates") unless valid_coordinates?(z, x, y)

    case layer.layer_provider
    when "martin" then render_martin(layer, z, x, y)
    when "cog" then render_cog(layer, z, x, y, params)
    when "gee" then render_earth_engine(layer, z, x, y)
    else failure(404, "Unsupported public tile provider")
    end
  rescue => e
    Rails.logger.error("[TileRendererService] Render failed: #{e.class}")
    failure(502, "Tile renderer request failed")
  end

  def self.render_cog_source(titiler_url:, cog_url:, z:, x:, y:, params: {})
    return failure(400, "Invalid tile coordinates") unless valid_coordinates?(z, x, y)
    return failure(400, "Invalid cogUrl") unless validated_cog_url(cog_url)
    titiler = validated_titiler_uri(titiler_url)
    return failure(400, "Invalid titilerUrl") unless titiler

    normalized = normalize_cog_variants(params, allow_missing: true)
    return failure(400, "Invalid tile parameters") unless normalized

    query = {"url" => cog_url}.merge(normalized)
    fetch_tile("#{titiler}/tiles/WebMercatorQuad/#{z}/#{x}/#{y}", query, cog_url, "image/png")
  end

  def self.public_cache_key(layer, z:, x:, y:, params: {})
    policy = TileSecurityPolicy.new(layer)
    TileByteCache.key(
      class: "public",
      layer_id: layer.id,
      source_key: policy.source_key,
      version: policy.version,
      representation: saved_representation(layer),
      coordinates: [z, x, y],
      params: params
    )
  end

  def self.public_representation_valid?(layer)
    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    case layer.layer_provider
    when "martin"
      source = body["source"]
      source.is_a?(String) && source != "scope_dataset_tiles" &&
        source.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
    when "cog"
      sources = cog_sources(body)
      return false unless public_temporal_variant_valid?(layer) && config["params"].blank?
      titiler_url = if body["url"].present?
        URI.parse(uri_with_temporal_templates(body["url"])).origin
      else
        ENV.fetch("TITILER_URL", "https://titiler.resilienceatlas.org")
      end
      variants = body.slice(*COG_VARIANT_KEYS)
      if body["url"].present?
        legacy_uri = URI.parse(uri_with_temporal_templates(body["url"]))
        variants = URI.decode_www_form(legacy_uri.query.to_s).to_h.slice(*COG_VARIANT_KEYS).merge(variants)
      end
      sources.length.between?(1, 32) && sources.all? { |source| validated_cog_url(source) } &&
        validated_titiler_uri(titiler_url).present? &&
        !normalize_cog_variants(variants, allow_missing: true).nil?
    when "gee"
      uri = URI.parse(body["url"].to_s)
      return false unless uri.is_a?(URI::HTTPS) && uri.host == "earthengine.googleapis.com" &&
        uri.port == 443 && uri.userinfo.nil? && uri.fragment.nil? &&
        uri.path.match?(%r{\A/v1/projects/[a-zA-Z0-9._:-]+/maps/[a-zA-Z0-9._:-]+/tiles/\{z\}/\{x\}/\{y\}\z})
      query = URI.decode_www_form(uri.query.to_s).to_h
      return false unless (query.keys - %w[token asset_id]).empty?
      return false if query["token"].present? && query["token"].bytesize > 4096
      analysis = parse_json(layer.analysis_body)
      configured_asset = body["assetId"] || body["asset_id"] || analysis["assetId"]
      configured_asset = query["asset_id"] if configured_asset.blank?
      configured_asset.present? &&
        (query["asset_id"].blank? || LayerDataSources.matches?(configured_asset, query["asset_id"]))
    else
      false
    end
  rescue JSON::ParserError, URI::InvalidURIError, ArgumentError, TypeError
    false
  end

  def self.public_temporal_variant_valid?(layer)
    return true unless layer.layer_provider == "cog"

    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    sources = cog_sources(body)
    return false if sources.empty?

    temporal_sources = sources.map { |source| source.match?(/\{\{(?:year|month|day)\}\}/) }
    if layer.timeline?
      temporal_sources.all? && temporal_sources.any?
    else
      temporal_sources.none?
    end
  rescue JSON::ParserError, URI::InvalidURIError, ArgumentError, TypeError
    false
  end

  def self.saved_representation(layer)
    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    case layer.layer_provider
    when "martin"
      {"source" => body["source"], "params" => body["params"]}
    when "cog"
      body.slice("url", "source", "sources", "clip_geometry", *COG_VARIANT_KEYS).merge(
        "timeline" => layer.timeline?,
        "timeline_steps" => Array.wrap(layer.timeline_steps).map(&:to_s),
        "timeline_start_date" => layer.timeline_start_date&.to_s,
        "timeline_end_date" => layer.timeline_end_date&.to_s
      )
    when "gee"
      {"url" => body["url"], "assetId" => body["assetId"], "asset_id" => body["asset_id"]}
    else
      {}
    end
  end

  def self.render_martin(layer, z, x, y)
    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    source = body.fetch("source")
    query = body.fetch("params", {})
    function = "public.ra_vector_tile"
    if source == "scope_dataset_tiles"
      return failure(403, "Scope dataset tiles are not public")
    elsif source != "ra_vector_tile"
      query = {"table" => source}
    end
    sql = ActiveRecord::Base.sanitize_sql_array(["SELECT #{function}(?, ?, ?, ?::json)", z, x, y, query.to_json])
    tile = ActiveRecord::Base.connection.select_value(sql)
    return failure(404, "Tile not found") if tile.blank?

    Result.new(status: 200, body: tile, content_type: "application/vnd.mapbox-vector-tile")
  end

  def self.render_cog(layer, z, x, y, params)
    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    index = Integer(params.fetch("source_index", "0"), exception: false)
    return failure(400, "Invalid COG source index") unless index&.between?(0, 31)

    source = cog_sources(body)[index]
    return failure(404, "COG source not found") unless source.is_a?(String)
    time = params["time"]
    timeline_template = source.match?(/\{\{(?:year|month|day)\}\}/)
    return failure(400, "A valid tile time is required") if timeline_template && time.blank?
    return failure(400, "Unexpected tile time") if !timeline_template && time.present?
    source = substitute_time(source, time, layer) if timeline_template
    return failure(400, "Invalid tile time") if timeline_template && source.blank?
    return failure(400, "Invalid COG source") unless validated_cog_url(source)

    variants = body.slice(*COG_VARIANT_KEYS)
    variants["feature"] ||= body["clip_geometry"]
    if body["url"].present?
      legacy_uri = URI.parse(uri_with_temporal_templates(body["url"]))
      legacy_query = URI.decode_www_form(legacy_uri.query.to_s).to_h
      variants = legacy_query.slice(*COG_VARIANT_KEYS).merge(variants)
      titiler_url = legacy_uri.origin
    else
      titiler_url = ENV.fetch("TITILER_URL", "https://titiler.resilienceatlas.org")
    end
    titiler = validated_titiler_uri(titiler_url)
    return failure(400, "Invalid TiTiler configuration") unless titiler
    normalized = normalize_cog_variants(variants, allow_missing: true)
    return failure(400, "Invalid COG representation") unless normalized

    fetch_tile(
      "#{titiler}/tiles/WebMercatorQuad/#{z}/#{x}/#{y}",
      {"url" => source}.merge(normalized),
      source,
      "image/png"
    )
  rescue URI::InvalidURIError, KeyError
    failure(400, "Invalid COG configuration")
  end

  def self.render_earth_engine(layer, z, x, y)
    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    template = body.fetch("url").to_s
    upstream_url = template.gsub("{z}", z.to_s).gsub("{x}", x.to_s).gsub("{y}", y.to_s)
    uri = URI.parse(upstream_url)
    query = URI.decode_www_form(uri.query.to_s)
    query_params = query.to_h
    valid_source = uri.is_a?(URI::HTTPS) && uri.host == "earthengine.googleapis.com" &&
      uri.port == 443 && uri.userinfo.nil? && uri.fragment.nil? &&
      (query_params.keys - %w[token asset_id]).empty? &&
      (!query_params["token"].present? || query_params["token"].bytesize <= 4096) &&
      (query_params["asset_id"].blank? || earth_engine_asset_matches?(layer, query_params["asset_id"]))
    return failure(400, "Invalid Earth Engine tile source") unless valid_source

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    result_from_response(response, "image/png")
  rescue URI::InvalidURIError
    failure(400, "Invalid Earth Engine tile source")
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[TileRendererService] Earth Engine timeout: #{e.class}")
    failure(504, "Earth Engine tile request timed out")
  end

  def self.cog_sources(body)
    sources = Array(body["sources"])
    sources = [body["source"]] if sources.empty? && body["source"].present?
    if sources.empty? && body["url"].present?
      query = URI.decode_www_form(URI.parse(uri_with_temporal_templates(body["url"])).query.to_s).to_h
      sources = [query["url"]].compact
    end
    sources
  end

  def self.substitute_time(source, value, layer)
    return unless value.match?(/\A\d{4}(?:-(?:0[1-9]|1[0-2])(?:-(?:0[1-9]|[12]\d|3[01]))?)?\z/)
    return unless source.match?(/\{\{(?:year|month|day)\}\}/)

    date_value = case value.length
    when 4 then "#{value}-01-01"
    when 7 then "#{value}-01"
    else value
    end
    date = Date.iso8601(date_value)
    normalize_timeline_source(source, date, layer)
  rescue ArgumentError
    nil
  end

  def self.normalize_timeline_source(source, date, layer)
    precision = if source.include?("{{day}}")
      3
    elsif source.include?("{{month}}")
      2
    else
      1
    end
    date_key = [date.year, date.month, date.day].take(precision)
    start_date = layer.timeline_start_date
    end_date = layer.timeline_end_date
    start_key = [start_date.year, start_date.month, start_date.day].take(precision) if start_date
    end_key = [end_date.year, end_date.month, end_date.day].take(precision) if end_date
    return if start_key && (date_key <=> start_key) == -1
    return if end_key && (date_key <=> end_key) == 1
    steps = Array.wrap(layer.timeline_steps).map(&:to_date)
    return if steps.present? && !steps.any? { |step| [step.year, step.month, step.day].take(precision) == date_key }

    source.gsub("{{year}}", date.strftime("%Y"))
      .gsub("{{month}}", date.strftime("%m"))
      .gsub("{{day}}", date.strftime("%d"))
  end

  def self.normalize_cog_variants(params, allow_missing:)
    input = params.to_h.stringify_keys.slice(*COG_VARIANT_KEYS)
    result = {}
    if input.key?("bidx")
      bands = input["bidx"]
      bands = bands.split(",") if bands.is_a?(String)
      bands = Array(bands)
      return unless bands.length.between?(1, 16) && bands.all? { |band| Integer(band, exception: false)&.between?(1, 64) }
      result["bidx"] = bands
    end
    if input.key?("resampling_method")
      return unless RESAMPLING_METHODS.include?(input["resampling_method"].to_s)
      result["resampling_method"] = input["resampling_method"].to_s
    end
    if input.key?("nodata")
      value = Float(input["nodata"], exception: false)
      return unless value&.finite?
      result["nodata"] = value.to_s
    end
    if input.key?("rescale")
      value = input["rescale"].to_s
      return unless value.match?(/\A-?\d+(?:\.\d+)?,?-?\d+(?:\.\d+)?(?:,-?\d+(?:\.\d+)?,?-?\d+(?:\.\d+)?)*\z/)
      result["rescale"] = value
    end
    if input.key?("colormap_name")
      name = input["colormap_name"].to_s
      return unless name.match?(/\A[a-zA-Z0-9_-]{1,64}\z/)
      result["colormap_name"] = name
    end
    if input.key?("colormap")
      colormap = input["colormap"]
      colormap = JSON.parse(colormap) if colormap.is_a?(String)
      return unless colormap.is_a?(Hash) || colormap.is_a?(Array)
      encoded = JSON.generate(colormap)
      return if encoded.bytesize > 32_768
      result["colormap"] = encoded
    end
    if input.key?("feature")
      feature = input["feature"]
      encoded = feature.is_a?(String) ? feature : JSON.generate(feature)
      return if encoded.bytesize > 32_768
      parsed = JSON.parse(encoded)
      return unless parsed.is_a?(Hash) && parsed["type"].in?(%w[Feature Polygon MultiPolygon])
      result["feature"] = encoded
    end
    result
  rescue JSON::ParserError, TypeError
    nil
  end

  def self.fetch_tile(url, query, source_url, content_type)
    uri = URI.parse("#{url}?#{URI.encode_www_form(query)}")
    request = Net::HTTP::Get.new(uri.request_uri)
    request["X-Data-Authorization"] = DataGatewaySignature.for(source_url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) do |http|
      http.request(request)
    end
    result_from_response(response, content_type)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("[TileRendererService] TiTiler timeout: #{e.class}")
    failure(504, "Tile renderer request timed out")
  rescue => e
    Rails.logger.error("[TileRendererService] TiTiler request failed: #{e.class}")
    failure(502, "Tile renderer request failed")
  end

  def self.result_from_response(response, content_type)
    status = response.code.to_i
    Result.new(
      status: status,
      body: response.body.to_s,
      content_type: content_type,
      error: (status == 200) ? nil : "Tile renderer request failed"
    )
  end

  def self.validated_cog_url(url)
    return false if url.blank?
    parsed_url = uri_with_temporal_templates(url)
    return false if parsed_url.blank?
    uri = URI.parse(parsed_url)
    if uri.scheme == "s3"
      allowed = (ENV["COG_ALLOWED_S3_BUCKETS"] || "resilienceatlas").split(",").map(&:strip)
      uri.host.present? && allowed.include?(uri.host)
    else
      uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? &&
        uri.query.nil? && uri.fragment.nil? &&
        COG_ALLOWED_HOSTS.any? { |pattern| uri.host.to_s.match?(pattern) }
    end
  rescue URI::InvalidURIError
    false
  end

  def self.validated_titiler_uri(url)
    uri = URI.parse(url.to_s)
    return unless uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? &&
      uri.query.nil? && uri.fragment.nil? && uri.path.in?(["", "/"]) &&
      TITILER_ALLOWED_HOSTS.any? { |pattern| uri.host.to_s.match?(pattern) }

    "#{uri.scheme}://#{uri.host}"
  rescue URI::InvalidURIError
    nil
  end

  def self.uri_with_temporal_templates(url)
    normalized = url.to_s.gsub(/\{\{(year|month|day)\}\}/) { |template| CGI.escape(template) }
    return if normalized.match?(/[{}]/)

    normalized
  end

  def self.parse_json(raw)
    JSON.parse(raw.presence || "{}")
  end

  def self.earth_engine_asset_matches?(layer, requested_asset)
    config = parse_json(layer.layer_config)
    body = config.fetch("body", config)
    analysis = parse_json(layer.analysis_body)
    configured_asset = body["assetId"] || body["asset_id"] || analysis["assetId"]
    configured_asset.present? && LayerDataSources.matches?(configured_asset, requested_asset)
  end

  def self.failure(status, error)
    Result.new(status: status, body: {"error" => error}.to_json, content_type: "application/json", error: error)
  end

  private_class_method :render_martin, :render_cog, :render_earth_engine, :cog_sources,
    :substitute_time, :normalize_timeline_source, :normalize_cog_variants, :fetch_tile, :result_from_response,
    :validated_cog_url, :validated_titiler_uri, :uri_with_temporal_templates, :parse_json,
    :earth_engine_asset_matches?, :failure
end
