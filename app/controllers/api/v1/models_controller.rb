module Api
  module V1
    class ModelsController < ApiController

      def index
        # TODO - Use strong params when arranged which to use
        @models = Model.fetch_all(params)
        render json: @models,
               meta: { total_models: @models.size},
               include: %i[indicators site_scopes]
      end
    end
  end
end
