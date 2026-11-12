require "digest"

class TileSecurityPolicy
  SUPPORTED_PROVIDERS = %w[martin cog gee].freeze

  def self.reports_for(layers)
    candidates = Layer.includes(:site_scopes).to_a
    index = Hash.new { |hash, key| hash[key] = [] }
    candidates.each do |candidate|
      new(candidate).dependency_keys.each { |key| index[key] << candidate }
    end
    imports = TileSourceImport.table_exists? ? TileSourceImport.blocking.to_a : []
    Array(layers).to_h { |layer| [layer.id, new(layer, alias_index: index, imports: imports).report] }
  end

  def initialize(layer, alias_index: nil, imports: nil)
    @layer = layer
    @alias_index = alias_index
    @imports = imports
  end

  def version
    @layer.tile_cache_version
  end

  def source_key
    identity = source_identity
    Digest::SHA256.hexdigest(JSON.generate([@layer.layer_provider, identity])) if identity.present?
  end

  def aliases
    return Layer.none unless source_key
    keys = dependency_keys
    return keys.flat_map { |key| @alias_index[key] }.uniq(&:id).reject { |candidate| candidate.id == @layer.id } if @alias_index
    Layer.where(layer_provider: @layer.layer_provider).where.not(id: @layer.id).select do |candidate|
      (self.class.new(candidate).dependency_keys & keys).any?
    end
  end

  def dependency_keys
    Array(source_identity).map { |identity| Digest::SHA256.hexdigest(JSON.generate([@layer.layer_provider, identity])) }
  end

  def public_cache_eligible?
    reasons.empty?
  end

  def anonymous_source_restricted?
    @layer.data_policy == "restricted" ||
      @layer.site_scopes.any?(&:password_protected?) ||
      aliases.any? { |candidate| candidate.data_policy == "restricted" || candidate.site_scopes.any?(&:password_protected?) }
  end

  def self.anonymous_restricted_layer_ids(layers)
    candidates = Layer.includes(:site_scopes).to_a
    index = Hash.new { |hash, key| hash[key] = [] }
    candidates.each { |candidate| new(candidate).dependency_keys.each { |key| index[key] << candidate } }
    layers.select { |layer| new(layer, alias_index: index).anonymous_source_restricted? }.map(&:id)
  end

  def report
    blocks = reasons
    warnings = diagnostic_warnings(blocks)
    status = warnings.any? ? "warning" : "ready"
    status = "blocked" if blocks.any?
    {"status" => status, "reasons" => (blocks + warnings).uniq,
     "config_diagnostics" => config_diagnostics,
     "source_key" => source_key, "version" => version, "public_cache_eligible" => blocks.empty?}
  end

  def config_diagnostics
    config = JSON.parse(@layer.layer_config.presence || "{}")
    return diagnostic("invalid_config_shape", "Layer config must be a JSON object.") unless config.is_a?(Hash)
    body = config.fetch("body", config)
    return diagnostic("invalid_body_shape", "Layer config body must be a JSON object.") unless body.is_a?(Hash)

    case @layer.layer_provider
    when "cog"
      if (body.key?("source") && !body["source"].is_a?(String)) ||
          (body.key?("sources") && (!body["sources"].is_a?(Array) || !body["sources"].all? { |source| source.is_a?(String) })) ||
          (body.key?("url") && !body["url"].is_a?(String))
        return diagnostic("invalid_source_shape", "COG source and url must be strings; sources must be an array of strings.")
      end
      sources = LayerDataSources.cog_urls(@layer)
      return diagnostic("missing_cog_source", "Set body.source, body.sources, or the url query parameter in body.url.") if sources.empty? || sources.any?(&:blank?)
      sources.each do |source|
        uri = URI.parse(escape_temporal_templates(source))
        unless uri.scheme.in?(%w[s3 https])
          return diagnostic("unsupported_source_scheme", "COG sources must use s3:// or https://.")
        end
        unless canonical_url(source)
          return diagnostic("invalid_source_url", "COG sources require a host and no embedded credentials; S3 sources also require an object key and no port, query or fragment.")
        end
      end
    when "martin"
      unless source_identity.present?
        return diagnostic("unresolved_martin_source", "Set body.params.table or source to a valid table identifier, not a generic tile function.")
      end
    when "gee"
      begin
        JSON.parse(@layer.analysis_body.presence || "{}")
      rescue JSON::ParserError
        return diagnostic("invalid_analysis_json", "Analysis body must contain valid JSON to resolve the Earth Engine asset.")
      end
      unless source_identity.present?
        return diagnostic("unresolved_gee_source", "Set an Earth Engine assetId/asset_id or a supported earthengine.googleapis.com map tile URL.")
      end
    else
      return diagnostic("missing_provider_config", "Set a nonempty provider configuration object.") if config.empty?
    end
    []
  rescue JSON::ParserError
    diagnostic("invalid_config_json", "Layer config must contain valid JSON.")
  rescue URI::InvalidURIError, ArgumentError
    diagnostic("invalid_source_url", "A COG source or tile URL is malformed; check URL encoding and timeline placeholders.")
  end

  def reasons
    codes = local_reasons
    if source_key
      codes << "conflicting_source_alias" if aliases.any? { |candidate| restricted?(candidate) }
    end
    imports = @imports || (TileSourceImport.table_exists? ? TileSourceImport.blocking : [])
    affected_imports = imports.select { |run| run.blocks?(@layer, source_key) }
    if affected_imports.any?
      codes << "source_import_in_progress"
    end
    if affected_imports.any? { |run| %w[failed reconciliation_required].include?(run.status) }
      codes << "import_security_reconciliation_failed"
      codes << "source_changed_review_required"
    end
    codes.uniq
  end

  def local_reasons
    codes = []
    codes << "draft_not_published" unless @layer.published?
    codes << "restricted_data_policy" if @layer.data_policy != "public"
    codes << "public_origin_explicitly_revoked" if explicit_revocation?(@layer)
    codes << "unsupported_provider" unless SUPPORTED_PROVIDERS.include?(@layer.layer_provider)
    codes << "invalid_provider_config" unless structurally_valid_config?
    scopes = @layer.site_scopes.distinct.to_a
    codes << "no_scope_assignment" if scopes.empty?
    codes << "protected_membership_blocks_public_origin" if scopes.any?(&:password_protected?)
    codes << "cache_generation_missing" if version.blank?
    codes
  end

  private

  def structurally_valid_config?
    config_diagnostics.empty?
  end

  def diagnostic(code, message)
    [{"code" => code, "message" => message}]
  end

  def diagnostic_warnings(blocks)
    codes = []
    if source_key && aliases.any? { |candidate| self.class.new(candidate).local_reasons.empty? }
      codes << "shared_source_public_alias"
    end
    if blocks.empty?
      origin = URI.parse(ENV.fetch("TILE_PUBLIC_CDN_URL", ""))
      unless origin.is_a?(URI::HTTPS) && origin.host.present? && origin.port == 443 &&
          origin.path.in?(["", "/"]) && origin.userinfo.nil? && origin.query.nil? && origin.fragment.nil?
        codes << "cache_route_not_active"
      end
    end
    codes
  rescue URI::InvalidURIError
    codes + ["cache_route_not_active"]
  end

  def explicit_revocation?(layer)
    layer.layer_provider == "martin" && layer.security_provenance == "explicit" && !layer.public_data?
  end

  def restricted?(layer)
    layer.data_policy != "public" || explicit_revocation?(layer) || layer.site_scopes.any?(&:password_protected?)
  end

  def source_identity
    config = JSON.parse(@layer.layer_config.presence || "{}")
    return unless config.is_a?(Hash)
    body = config.fetch("body", config)
    return unless body.is_a?(Hash)
    case @layer.layer_provider
    when "martin"
      table = body.dig("params", "table") || body["source"] || config["source"]
      table if table.is_a?(String) && table.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/) && !%w[scope_dataset_tiles ra_vector_tile].include?(table)
    when "cog"
      sources = LayerDataSources.cog_urls(@layer)
      return if sources.empty?
      normalized = sources.map { |source| canonical_url(source) }
      normalized.sort if normalized.all?
    when "gee"
      analysis = JSON.parse(@layer.analysis_body.presence || "{}")
      asset = body["assetId"] || body["asset_id"] || analysis["assetId"]
      if asset.blank? && body["url"].is_a?(String)
        uri = URI.parse(body["url"].gsub("{", "%7B").gsub("}", "%7D"))
        path = URI::DEFAULT_PARSER.unescape(uri.path)
        asset = URI.decode_www_form(uri.query.to_s).to_h["asset_id"]
        if asset.blank? && uri.is_a?(URI::HTTPS) && uri.host == "earthengine.googleapis.com" &&
            uri.port == 443 && uri.userinfo.nil? && uri.fragment.nil? &&
            path.match?(%r{\A/v1/projects/[a-zA-Z0-9._:-]+/maps/[a-zA-Z0-9._:-]+/tiles/\{z\}/\{x\}/\{y\}\z})
          return "earthengine-map:#{path}"
        end
      end
      asset if asset.is_a?(String) && asset.match?(/\A[a-zA-Z0-9_{}\/.:-]+\z/)
    end
  rescue JSON::ParserError, URI::InvalidURIError, ArgumentError, TypeError, NoMethodError
    nil
  end

  def canonical_url(value)
    uri = URI.parse(escape_temporal_templates(value))
    if uri.scheme == "s3"
      return unless uri.host&.match?(/\A[a-z0-9][a-z0-9.-]*\z/) && uri.path.present? && uri.path != "/" &&
        uri.userinfo.nil? && uri.port.nil? && uri.query.nil? && uri.fragment.nil?

      return "https://#{uri.host}.s3.amazonaws.com#{uri.path}"
    end
    return unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?
    # Credentials never participate in alias identity: signed and unsigned aliases
    # for the same object must share restrictions.
    host = uri.host.downcase
    path = uri.path
    if uri.port == 443
      if (match = host.match(/\A(.+)\.s3(?:[.-](?:dualstack\.)?[a-z0-9-]+)?\.amazonaws\.com\z/))
        host = "#{match[1]}.s3.amazonaws.com"
      elsif host.match?(/\As3(?:[.-](?:dualstack\.)?[a-z0-9-]+)?\.amazonaws\.com\z/) &&
          (match = path.match(%r{\A/([a-z0-9][a-z0-9.-]*)/(.+)\z}))
        host = "#{match[1]}.s3.amazonaws.com"
        path = "/#{match[2]}"
      end
    end
    "#{uri.scheme}://#{host}#{(uri.port == 443) ? "" : ":#{uri.port}"}#{path}"
  end

  def escape_temporal_templates(value)
    value.gsub(/\{\{(year|month|day)\}\}/) { |token| token.gsub("{", "%7B").gsub("}", "%7D") }
  end
end
