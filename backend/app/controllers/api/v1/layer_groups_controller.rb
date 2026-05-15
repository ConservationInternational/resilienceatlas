module Api
  module V1
    class LayerGroupsController < ApiController
      include SitesFilters

      def index
        @layer_groups = LayerGroup.fetch_all(layers_params)
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: @layer_groups, meta: {total_layer_groups: @layer_groups.size}
      end
    end
  end
end
