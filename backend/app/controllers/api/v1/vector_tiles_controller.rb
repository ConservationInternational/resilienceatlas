module Api
  module V1
    class VectorTilesController < ApiController
      include SitesFilters

      def show
        preview = authorized_preview?
        layer = preview ? preview_layer : Layer.fetch_all(layers_params).where(layer_provider: "martin").find(params[:id])
        raise ActiveRecord::RecordNotFound unless layer.layer_provider == "martin"
        unless restricted_tile_access_allowed?(layer, preview: preview)
          response.cache_control.replace(no_store: true, private: true)
          return render json: {error: "Tile is not available"}, status: :forbidden
        end
        if source_import_blocked?(layer)
          response.cache_control.replace(no_store: true, private: true)
          return render json: {error: "Tile source is being updated"}, status: :service_unavailable
        end
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
        policy = TileSecurityPolicy.new(layer)
        cache_key = if policy.version.present?
          TileByteCache.key(
            class: "private",
            layer_id: layer.id,
            source_key: policy.source_key,
            version: policy.version,
            scope_id: @site_scope.id,
            function: function,
            representation: query,
            coordinates: [z, x, y]
          )
        end
        tile = TileByteCache.fetch(cache_key, bypass: preview) do
          {status: 200, body: ActiveRecord::Base.connection.select_value(sql).to_s}
        end[:body]
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

      def source_import_blocked?(layer)
        return false unless defined?(TileSourceImport) && TileSourceImport.table_exists?

        key = TileSecurityPolicy.new(layer).source_key
        TileSourceImport.blocking.any? { |run| run.blocks?(layer, key) }
      end

      def restricted_tile_access_allowed?(layer, preview: false)
        return true if preview || (respond_to?(:current_admin_user, true) && current_admin_user&.superadmin?)
        return true unless layer.respond_to?(:data_policy) && layer.data_policy == "restricted"

        @site_scope&.requires_authentication?
      end
    end
  end
end
