module Api
  module V1
    class EarthEngineController < ApiController
      include SitesFilters

      def show
        proxy_request
      end

      def create
        proxy_request
      end

      def tile
        z, x, y = %i[z x y].map { |key| Integer(params[key], exception: false) }
        unless z && x && y && z.between?(0, 22) && x.between?(0, 2**z - 1) && y.between?(0, 2**z - 1)
          return render json: {error: "Invalid tile coordinates"}, status: :bad_request
        end
        layer = authorized_preview? ? preview_layer : Layer.fetch_all(layers_params).where(layer_provider: "gee").find(params[:layer_id])
        raise ActiveRecord::RecordNotFound unless layer.layer_provider == "gee"
        config = JSON.parse(layer.layer_config.presence || "{}")
        template = config.dig("body", "url").to_s
        uri = URI(template.gsub("{z}", z.to_s).gsub("{x}", x.to_s).gsub("{y}", y.to_s))
        unless uri.is_a?(URI::HTTPS) && uri.host == "earthengine.googleapis.com" && uri.port == 443 && !uri.userinfo && !uri.fragment
          Rails.logger.warn "[EarthEngineController] Rejected tile source for layer #{layer.id}"
          return render json: {error: "Invalid Earth Engine tile source"}, status: :bad_request
        end
        result = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 30) { |http| http.request(Net::HTTP::Get.new(uri)) }
        response.cache_control.replace(no_store: true, private: true)
        render body: result.body, content_type: "image/png", status: result.code.to_i
      rescue URI::InvalidURIError
        render json: {error: "Invalid Earth Engine tile source"}, status: :bad_request
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error "[EarthEngineController] #{e.class}"
        render json: {error: "Earth Engine tile request timed out"}, status: :gateway_timeout
      end

      private

      def preview_layer
        @preview_layer ||= AdminPreviewAccess.resolve(params[:admin_preview_token], Layer)
      end

      def authorized_preview?
        action_name == "tile" && preview_layer && preview_layer.id.to_s == params[:layer_id] &&
          preview_layer.site_scopes.exists?(id: @site_scope.id)
      end

      def proxy_request
        operation = params[:operation]
        unless %w[histogram raster download].include?(operation)
          return render json: {error: "Unknown operation"}, status: :not_found
        end
        valid_method = (operation == "raster") ? request.get? : request.post?
        unless valid_method
          return render json: {error: "Invalid method for operation"}, status: :method_not_allowed
        end
        layer = Layer.fetch_all(layers_params).where(layer_provider: "gee").find(params[:layer_id])
        asset = params[:assetId].presence || params[:asset_id]
        configured = JSON.parse(layer.analysis_body.presence || "{}")["assetId"]
        interaction = JSON.parse(layer.interaction_config.presence || "{}")
        query = interaction.dig("config", "url").to_s.split("?", 2).last.to_s
        assets = [configured] + URI.decode_www_form(query).to_h.slice("asset_id").values
        unless asset.is_a?(String) && assets.compact.any? { |source| LayerDataSources.matches?(source, asset) }
          return render json: {error: "Asset is not available in this layer"}, status: :forbidden
        end
        base = URI(ENV.fetch("EARTH_ENGINE_API_URL"))
        raise ArgumentError, "EARTH_ENGINE_API_URL must be an HTTPS origin" unless base.is_a?(URI::HTTPS) && base.port == 443 && base.path.in?(["", "/"]) && !base.userinfo && !base.query && !base.fragment

        uri = URI.join(base.to_s, operation)
        if operation == "raster"
          uri.query = URI.encode_www_form(asset_id: asset, point: params[:point])
          upstream_request = Net::HTTP::Get.new(uri)
        else
          upstream_request = Net::HTTP::Post.new(uri)
          upstream_request["Content-Type"] = "application/json"
          upstream_request.body = request.request_parameters.slice("geometry", "numBuckets", "scale", "crs", "format").merge("assetId" => asset).to_json
        end
        upstream_request["X-Data-Authorization"] = DataGatewaySignature.for(asset)
        result = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 120) { |http| http.request(upstream_request) }
        response.cache_control.replace(no_store: true, private: true)
        render body: result.body, content_type: "application/json", status: result.code.to_i
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        Rails.logger.error "[EarthEngineController] #{e.class}"
        render json: {error: "Earth Engine request timed out"}, status: :gateway_timeout
      end
    end
  end
end
