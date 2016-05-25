module Api
  module V1
    class LayersController < ApiController
    include SitesFilters
    skip_before_action :create_site_scope
      def index
        @layers = Layer.fetch_all(layers_params)
        render json: @layers, meta:{total_layers: @layers.size}, include: ['layer_groups'], site_scope: layers_params[:site_scope].to_i
      end
    end
  end
end
