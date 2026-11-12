require "net/http"

class TileSecurityProbe
  def self.request!(layer, actor)
    Ability.new(actor).authorize! :read, layer
    verification = layer.with_lock do
      if TileSecurityVerification.where(layer: layer, admin_user: actor).where("created_at > ?", 1.minute.ago).exists?
        raise ArgumentError, "Wait one minute before requesting another verification"
      end
      TileSecurityVerification.create!(layer: layer, admin_user: actor,
        source_version: TileSecurityPolicy.new(layer).version)
    end
    TileSecurityProbeJob.perform_async(verification.id)
    verification
  rescue RedisClient::Error => error
    verification&.update!(status: "failed", results: {"error" => "Verification queue unavailable"})
    Rails.logger.error "[TileSecurityProbe] Queue unavailable (#{error.class})"
    raise ArgumentError, "Verification queue unavailable; retry after worker/Redis recovery"
  end

  def initialize(verification)
    @verification = verification
  end

  def call
    layer = @verification.layer
    Ability.new(@verification.admin_user).authorize! :read, layer
    policy = TileSecurityPolicy.new(layer)
    if @verification.source_version != policy.version
      return @verification.update!(status: "stale", results: {"error" => "Source or policy changed"})
    end
    origins = {"cdn" => ENV["TILE_PUBLIC_CDN_URL"], "origin" => ENV["TILE_ORIGIN_PROBE_URL"]}.compact_blank
    raise ArgumentError, "Configure fixed CDN and/or origin probe URLs before verification" if origins.empty?
    results = origins.transform_values { |origin| probe(origin, layer, policy) }
    @verification.update!(status: (results.values.all? { |result| result["passed"] }) ? "passed" : "failed", results: results)
  rescue ArgumentError, CanCan::AccessDenied, URI::InvalidURIError, SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => error
    Rails.logger.error "[TileSecurityProbe #{@verification.id}] #{error.class}"
    @verification.update!(status: "failed", results: {"error" => error.is_a?(ArgumentError) ? error.message : "Verification failed (#{error.class})"})
  end

  private

  def probe(origin, layer, policy)
    base = URI(origin)
    unless base.is_a?(URI::HTTPS) && base.port == 443 && base.host.present? && !base.userinfo && !base.query && !base.fragment
      raise ArgumentError, "Probe origins must be fixed HTTPS/443 URLs without credentials, query or fragment"
    end
    uri = URI.join("#{base.to_s.chomp("/")}/", "/api/public-tiles/#{layer.id}/#{policy.version}/0/0/0")
    bytes = 0
    prefix = "".b
    result = {}
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        response.read_body do |chunk|
          bytes += chunk.bytesize
          raise ArgumentError, "Probe response exceeds 2 MiB limit" if bytes > 2.megabytes
          prefix << chunk.b.byteslice(0, 12 - prefix.bytesize) if prefix.bytesize < 12
        end
        allowed_types = %w[image/png image/jpeg image/webp application/x-protobuf application/vnd.mapbox-vector-tile]
        content_type = response["Content-Type"].to_s.split(";").first
        passed = if policy.public_cache_eligible?
          response.code == "200" && bytes.positive? && allowed_types.include?(content_type) && tile_signature?(prefix, content_type)
        else
          %w[401 403 404].include?(response.code)
        end
        result = {"passed" => passed, "http_status" => response.code.to_i, "bytes" => bytes,
                  "content_type" => content_type, "cache" => response["X-Cache"].to_s.truncate(100),
                  "expected" => policy.public_cache_eligible? ? "public_tile" : "denied",
                  "note" => bytes.zero? ? "Empty response; rendering not demonstrated" : "Anonymous request, no preview credentials"}
      end
    end
    result
  end

  def tile_signature?(prefix, content_type)
    case content_type
    when "image/png" then prefix.start_with?("\x89PNG\r\n\x1a\n".b)
    when "image/jpeg" then prefix.start_with?("\xff\xd8\xff".b)
    when "image/webp" then prefix.start_with?("RIFF") && prefix.byteslice(8, 4) == "WEBP"
    else prefix.getbyte(0) == 0x1a && prefix.bytesize >= 3
    end
  end
end
