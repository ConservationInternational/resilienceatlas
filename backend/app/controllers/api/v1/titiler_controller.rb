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

        # Validate URLs to prevent SSRF attacks
        unless valid_titiler_url?(titiler_url)
          return render json: {error: "Invalid titilerUrl"}, status: :bad_request
        end

        begin
          # Build the TiTiler info URL
          info_url = "#{titiler_url}/info?url=#{CGI.escape(cog_url)}"

          # Make the request to TiTiler
          uri = URI.parse(info_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 10
          http.read_timeout = 30

          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)

          # Forward the response
          render json: response.body, status: response.code.to_i
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          Rails.logger.error "[TitilerController] Timeout fetching COG info: #{e.message}"
          render json: {error: "Request to TiTiler timed out"}, status: :gateway_timeout
        rescue StandardError => e
          Rails.logger.error "[TitilerController] Error fetching COG info: #{e.message}"
          render json: {error: "Failed to fetch COG info from TiTiler"}, status: :internal_server_error
        end
      end

      private

      # Validate that the titiler URL is an allowed TiTiler instance
      # This prevents SSRF attacks by ensuring we only proxy to known TiTiler servers
      def valid_titiler_url?(url)
        return false if url.blank?

        begin
          uri = URI.parse(url)
          return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

          # Allow known TiTiler domains
          allowed_patterns = [
            /\Atitiler\.resilienceatlas\.org\z/,
            /\A[\w-]+\.titiler\.resilienceatlas\.org\z/,  # staging.titiler.resilienceatlas.org, etc.
            /\Alocalhost(:\d+)?\z/  # Development
          ]

          allowed_patterns.any? { |pattern| uri.host.match?(pattern) }
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
