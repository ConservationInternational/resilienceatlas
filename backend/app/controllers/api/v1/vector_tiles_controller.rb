module Api
  module V1
    class VectorTilesController < ApiController
      include SitesFilters

      def show
        layer = authorized_preview? ? preview_layer : Layer.fetch_all(layers_params).where(layer_provider: "martin").find(params[:id])
        raise ActiveRecord::RecordNotFound unless layer.layer_provider == "martin"
        config = JSON.parse(layer.layer_config)
        body = config.fetch("body", config)
        source = body.fetch("source")
        query = body.fetch("params", {})
        function = "ra_app.private_ra_vector_tile"
        if source == "scope_dataset_tiles"
          dataset = ScopeDataset.find_by!(id: query["scope_dataset_id"], site_scope_id: @site_scope.id)
          query = {"scope_dataset_id" => dataset.id}
          function = "ra_app.scope_dataset_tiles"
        elsif source != "ra_vector_tile"
          query = {"table" => source}
        end
        z, x, y = %i[z x y].map { |key| Integer(params[key], exception: false) }
        unless z && x && y && z.between?(0, 22) && x.between?(0, 2**z - 1) && y.between?(0, 2**z - 1)
          return render json: {error: "Invalid tile coordinates"}, status: :bad_request
        end
        sql = ActiveRecord::Base.sanitize_sql_array(["SELECT #{function}(?, ?, ?, ?::json)", z, x, y, query.to_json])
        tile = ActiveRecord::Base.connection.select_value(sql)
        response.cache_control.replace(no_store: true, private: true)
        send_data tile, type: "application/vnd.mapbox-vector-tile", disposition: "inline"
      end

      private

      def preview_layer
        @preview_layer ||= AdminPreviewAccess.resolve(params[:admin_preview_token], Layer)
      end

      def authorized_preview?
        preview_layer && preview_layer.id.to_s == params[:id] && preview_layer.site_scopes.exists?(id: @site_scope.id)
      end
    end
  end
end
