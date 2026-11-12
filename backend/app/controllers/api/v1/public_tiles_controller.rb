module Api
  module V1
    class PublicTilesController < ApiController
      before_action :validate_public_tile_request

      def show
        policy = tile_policy
        unless policy.public_cache_eligible? && secure_version_match?(policy.version, params[:version])
          return no_store_error(:not_found, "Public tile not available")
        end

        tile_params = normalized_tile_params
        return no_store_error(:bad_request, "Invalid tile parameters") unless tile_params

        cache_key = TileRendererService.public_cache_key(
          @layer,
          z: @z,
          x: @x,
          y: @y,
          params: tile_params
        )
        result = TileByteCache.fetch(cache_key) do
          rendered = TileRendererService.render(@layer, z: @z, x: @x, y: @y, params: tile_params)
          {status: rendered.status, body: rendered.body, content_type: rendered.content_type}
        end

        unless result[:status].to_i == 200 && result[:body].is_a?(String) &&
            result[:body].bytesize.between?(1, TileByteCache::MAX_BYTES)
          status = (result[:status].to_i == 400) ? :bad_request : :bad_gateway
          return no_store_error(status, "Tile unavailable")
        end

        response.headers["Access-Control-Allow-Origin"] = "*"
        send_data result[:body], type: result[:content_type], disposition: "inline", status: :ok
        response.headers["Cache-Control"] = "public, max-age=0, s-maxage=86400"
      end

      private

      def validate_public_tile_request
        @z, @x, @y = %i[z x y].map { |key| Integer(params[key], exception: false) }
        unless TileRendererService.valid_coordinates?(@z, @x, @y)
          return no_store_error(:bad_request, "Invalid tile coordinates")
        end

        unknown_query = request.query_parameters.keys - %w[source_index time]
        return no_store_error(:bad_request, "Unsupported tile parameter") if unknown_query.any?

        @layer = Layer.find_by(id: params[:id])
        return no_store_error(:not_found, "Public tile not available") unless @layer

        policy = tile_policy
        unless @layer.layer_provider.in?(TileSecurityPolicy::SUPPORTED_PROVIDERS) &&
            policy.public_cache_eligible? && TileRendererService.public_representation_valid?(@layer) &&
            secure_version_match?(policy.version, params[:version])
          no_store_error(:not_found, "Public tile not available")
        end
      end

      def normalized_tile_params
        return {} if @layer.layer_provider != "cog" && request.query_parameters.empty?
        return unless @layer.layer_provider == "cog"

        values = {}
        if params[:source_index].present?
          index = Integer(params[:source_index], exception: false)
          return unless index&.between?(0, 31)
          values["source_index"] = index.to_s
        end
        if params[:time].present?
          time = params[:time].to_s
          return unless time.match?(/\A\d{4}(?:-(?:0[1-9]|1[0-2])(?:-(?:0[1-9]|[12]\d|3[01]))?)?\z/)
          values["time"] = time
        end
        values
      end

      def secure_version_match?(current, requested)
        current.present? && requested.is_a?(String) &&
          ActiveSupport::SecurityUtils.secure_compare(current.to_s, requested)
      end

      def tile_policy
        @tile_policy ||= TileSecurityPolicy.new(@layer)
      end

      def no_store_error(status, message)
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.cache_control.replace(no_store: true, private: true)
        render json: {error: message}, status: status
      end
    end
  end
end
