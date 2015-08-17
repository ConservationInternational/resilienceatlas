module Api
  module V1
    class LayerGroupsController < ApiController
      def index
        @layer_groups = LayerGroup.all
        render json: @layer_groups, meta:{total_layer_groups: @layer_groups.size}
      end
    end
  end
end
