module Api
  module V1
    class ModelsController < ApiController

      def index
        # TODO - Use strong params when arranged which to use
        @models = Model.fetch_all(model_params)
        render json: @models,
               meta: { total_models: @models.size},
               include: %i[indicators site_scopes]
      end

      private
      def model_params
        params.permit(:site_scope)
      end
    end
  end
end
