module Api
  module V1
    class LayerGroupsController < ApiController
      include SitesFilters
      skip_before_action :create_site_scope
      def index
        @layer_groups = LayerGroup.fetch_all(layers_params)
        render json: @layer_groups, meta:{total_layer_groups: @layer_groups.size}
      end
    end
  end
end
