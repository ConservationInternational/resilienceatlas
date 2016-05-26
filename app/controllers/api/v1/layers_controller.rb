module Api
  module V1
    class LayersController < ApiController
    include SitesFilters
      def index
        @layers = Layer.fetch_all(layers_params)
        render json: @layers, meta:{total_layers: @layers.size}, include: ['layer_groups'], site_scope: layers_params[:site_scope].to_i
      end
    end
  end
end
