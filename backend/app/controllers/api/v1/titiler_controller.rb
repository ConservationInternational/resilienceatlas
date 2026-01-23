module Api
  module V1
    class TitilerController < ApiController
      # GET /api/titiler/info
      # Proxies requests to TiTiler's /info endpoint to fetch COG metadata.
      # This avoids CORS issues when the frontend requests COG bounds.
      #
      # Parameters:
      #   titilerUrl - The base URL of the TiTiler instance (e.g., https://staging.titiler.resilienceatlas.org)
      #   cogUrl - The URL of the COG file to get info for
      #
      # Returns:
      #   JSON response from TiTiler containing COG metadata including bounds
      def info
        titiler_url = params[:titilerUrl]
        cog_url = params[:cogUrl]

        if titiler_url.blank? || cog_url.blank?
          return render json: {error: "Missing required parameters: titilerUrl and cogUrl"}, status: :bad_request
        end

        proxy_get_request(titiler_url, "/info", {url: cog_url})
      end

      # POST /api/titiler/statistics
      # Proxies requests to TiTiler's /statistics endpoint for histogram analysis.
      # Accepts a GeoJSON geometry in the request body to compute statistics within that area.
      #
      # Parameters:
      #   titilerUrl - The base URL of the TiTiler instance
      #   cogUrl - The URL of the COG file to analyze
      #   bidx (optional) - Band index (1-based)
      #   categorical (optional) - Whether to treat data as categorical
      #   histogram_bins (optional) - Number of histogram bins
      #
      # Request body:
      #   GeoJSON Feature or FeatureCollection defining the analysis area
      #
      # Returns:
      #   JSON response from TiTiler with statistics including histogram
      def statistics
        titiler_url = params[:titilerUrl]
        cog_url = params[:cogUrl]

        if titiler_url.blank? || cog_url.blank?
          return render json: {error: "Missing required parameters: titilerUrl and cogUrl"}, status: :bad_request
        end

        # Build query params
        query_params = {url: cog_url}
        query_params[:bidx] = params[:bidx] if params[:bidx].present?
        query_params[:categorical] = params[:categorical] if params[:categorical].present?
        query_params[:histogram_bins] = params[:histogram_bins] if params[:histogram_bins].present?

        # Get GeoJSON from request body
        geojson = request.body.read

        proxy_post_request(titiler_url, "/statistics", query_params, geojson)
      end

      # GET /api/titiler/point
      # Proxies requests to TiTiler's /point/{lon}/{lat} endpoint for raster point queries.
      # Returns pixel values at the specified coordinates.
      #
      # Parameters:
      #   titilerUrl - The base URL of the TiTiler instance
      #   cogUrl - The URL of the COG file to query
      #   lon - Longitude of the point
      #   lat - Latitude of the point
      #   bidx (optional) - Band index (1-based)
      #
      # Returns:
      #   JSON response from TiTiler with pixel values at the point
      def point
        titiler_url = params[:titilerUrl]
        cog_url = params[:cogUrl]
        lon = params[:lon]
        lat = params[:lat]

        if titiler_url.blank? || cog_url.blank? || lon.blank? || lat.blank?
          return render json: {error: "Missing required parameters: titilerUrl, cogUrl, lon, lat"}, status: :bad_request
        end

        # Validate coordinates
        lon_f = Float(lon, exception: false)
        lat_f = Float(lat, exception: false)
        unless lon_f && lat_f && lon_f.between?(-180, 180) && lat_f.between?(-90, 90)
          return render json: {error: "Invalid coordinates"}, status: :bad_request
        end

        # Build query params
        query_params = {url: cog_url}
        query_params[:bidx] = params[:bidx] if params[:bidx].present?

        proxy_get_request(titiler_url, "/point/#{lon_f}/#{lat_f}", query_params)
      end

      private

      # Proxy a GET request to TiTiler
      def proxy_get_request(titiler_url, path, query_params)
        validated_uri = validated_titiler_uri(titiler_url)
        unless validated_uri
          return render json: {error: "Invalid titilerUrl"}, status: :bad_request
        end

        begin
          query_string = query_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
          uri = URI.parse("#{validated_uri}#{path}?#{query_string}")

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = 30

          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)

          render json: response.body, status: response.code.to_i
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          Rails.logger.error "[TitilerController] Timeout: #{e.message}"
          render json: {error: "Request to TiTiler timed out"}, status: :gateway_timeout
        rescue => e
          Rails.logger.error "[TitilerController] Error: #{e.message}"
          render json: {error: "Failed to fetch data from TiTiler"}, status: :internal_server_error
        end
      end

      # Proxy a POST request to TiTiler
      def proxy_post_request(titiler_url, path, query_params, body)
        validated_uri = validated_titiler_uri(titiler_url)
        unless validated_uri
          return render json: {error: "Invalid titilerUrl"}, status: :bad_request
        end

        begin
          query_string = query_params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&")
          uri = URI.parse("#{validated_uri}#{path}?#{query_string}")

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = 60 # Statistics can take longer

          request = Net::HTTP::Post.new(uri.request_uri)
          request["Content-Type"] = "application/json"
          request.body = body
          response = http.request(request)

          render json: response.body, status: response.code.to_i
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          Rails.logger.error "[TitilerController] Timeout: #{e.message}"
          render json: {error: "Request to TiTiler timed out"}, status: :gateway_timeout
        rescue => e
          Rails.logger.error "[TitilerController] Error: #{e.message}"
          render json: {error: "Failed to fetch data from TiTiler"}, status: :internal_server_error
        end
      end

      # Validate that the titiler URL is an allowed TiTiler instance and return the validated URI
      # This prevents SSRF attacks by ensuring we only proxy to known TiTiler servers
      # Returns the validated URI string or nil if invalid
      def validated_titiler_uri(url)
        return nil if url.blank?

        begin
          uri = URI.parse(url)
          return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

          # Allow known TiTiler domains
          allowed_patterns = [
            /\Atitiler\.resilienceatlas\.org\z/,
            /\A[\w-]+\.titiler\.resilienceatlas\.org\z/,  # staging.titiler.resilienceatlas.org, etc.
            /\Alocalhost(:\d+)?\z/  # Development
          ]

          return nil unless allowed_patterns.any? { |pattern| uri.host.match?(pattern) }

          # Return sanitized URI (scheme + host + port only)
          "#{uri.scheme}://#{uri.host}#{(uri.port == uri.default_port) ? "" : ":#{uri.port}"}"
        rescue URI::InvalidURIError
          nil
        end
      end
    end
  end
end
