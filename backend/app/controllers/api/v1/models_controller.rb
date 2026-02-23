module Api
  module V1
    class ModelsController < ApiController
      def index
        @models = Model.fetch_all(model_params).with_translations
          .includes(:site_scopes, indicators: [:translations, :category])
        render json: @models,
          meta: {total_models: @models.size},
          include: [:site_scopes, :indicators, "indicators.category"]
      end

      private

      def model_params
        params.permit(:site_scope)
      end
    end
  end
end
