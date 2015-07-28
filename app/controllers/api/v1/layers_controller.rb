module Api
  module V1
    class LayersController < ApiController
      def index
        @layers = Layer.all
        render json: @layers, meta:{total_layers: @layers.size}, include: ['layer_group']
      end
    end
  end
end
