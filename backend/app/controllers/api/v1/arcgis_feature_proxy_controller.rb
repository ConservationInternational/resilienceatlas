module Api
  module V1
    class ArcgisFeatureProxyController < ApiController
      # GET /api/v1/arcgis-feature-proxy/:id/query
      #
      # Proxies ArcGIS FeatureServer /query requests server-side so that API
      # tokens stored in layer_config are never exposed to the browser.
      #
      # Path params:
      #   id - Layer ID
      #
      # Query params:
      #   All standard ArcGIS REST /query params are forwarded verbatim
      #   (f, geometry, geometryType, inSR, outSR, outFields, where,
      #    spatialRel, returnGeometry, etc.)
      #
      # Configuration (layer_config.body):
      #   url   - FeatureServer layer URL (e.g. .../FeatureServer/0)
      #   token - ArcGIS API token (never exposed in the API response)
      #
      # SSRF protection:
      #   The target URL is validated against ARCGIS_ALLOWED_HOSTS (comma-
      #   separated list of hostname patterns in the environment) plus a
      #   built-in default allowlist of *.arcgis.com subdomains.
      def query
        layer = Layer.find_by(id: params[:id])
        return render json: {error: "Layer not found"}, status: :not_found unless layer

        unless layer.layer_provider == "arcgis_feature"
          return render json: {error: "Layer is not an arcgis_feature provider"}, status: :bad_request
        end

        begin
          config = JSON.parse(layer.layer_config || "{}")
        rescue JSON::ParserError
          return render json: {error: "Invalid layer_config"}, status: :internal_server_error
        end

        body = config.dig("body") || {}
        arcgis_url = body["url"]
        token = body["token"]

        if arcgis_url.blank?
          return render json: {error: "No url in layer_config.body"}, status: :bad_request
        end

        validated_url = validated_arcgis_uri(arcgis_url)
        unless validated_url
          return render json: {error: "ArcGIS URL is not in the allowed hosts list"}, status: :bad_request
        end

        # Forward all incoming query params except Rails routing internals,
        # then append the token server-side if present.
        forwarded_params = params.except(:controller, :action, :id).permit!.to_h
        forwarded_params["token"] = token if token.present?

        proxy_arcgis_query(validated_url, forwarded_params)
      end

      private

      # Proxy a GET request to ArcGIS FeatureServer /query and relay the
      # response back to the browser.
      def proxy_arcgis_query(base_url, query_params)
        query_string = query_params.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join("&")
        uri = URI.parse("#{base_url}/query?#{query_string}")

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30

        request = Net::HTTP::Get.new(uri.request_uri)
        response = http.request(request)

        content_type = response["Content-Type"] || "application/json"
        render body: response.body, content_type: content_type, status: response.code.to_i
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error "[ArcgisFeatureProxyController] Timeout proxying layer #{params[:id]}: #{e.message}"
        render json: {error: "Request to ArcGIS timed out"}, status: :gateway_timeout
      rescue => e
        Rails.logger.error "[ArcgisFeatureProxyController] Error proxying layer #{params[:id]}: #{e.message}"
        render json: {error: "Failed to fetch data from ArcGIS"}, status: :internal_server_error
      end

      # Default allowed hostname patterns for ArcGIS services.
      # Any *.arcgis.com subdomain is allowed out of the box. Operators can
      # extend this by setting ARCGIS_ALLOWED_HOSTS to a comma-separated list
      # of additional hostnames (exact match or *.domain patterns).
      ARCGIS_DEFAULT_ALLOWED = [
        /\A[\w.-]+\.arcgis\.com\z/,
        /\Alocalhost(:\d+)?\z/
      ].freeze

      # Validates an ArcGIS FeatureServer URL against the SSRF allowlist.
      # Returns the sanitized URL string (scheme + host + path) when valid,
      # or nil when the host is not allowed.
      def validated_arcgis_uri(url)
        return nil if url.blank?

        uri = URI.parse(url)
        return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

        host = uri.host.to_s

        # Check default patterns
        return url if ARCGIS_DEFAULT_ALLOWED.any? { |pattern| host.match?(pattern) }

        # Check operator-configured additional hosts
        extra_hosts = ENV.fetch("ARCGIS_ALLOWED_HOSTS", "")
          .split(",")
          .map(&:strip)
          .reject(&:empty?)

        extra_hosts.each do |allowed|
          if allowed.start_with?("*.")
            domain = Regexp.escape(allowed[2..])
            return url if host.match?(/\A[\w.-]+\.#{domain}\z/) || host == allowed[2..]
          elsif host == allowed
            return url
          end
        end

        nil
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
