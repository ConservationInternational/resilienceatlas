module Api
  module V1
    class JourneysController < ApiController
      def index
        journeys = Journey.with_translations
          .includes(background_image_attachment: [:blob], journey_steps: [:translations, background_image_attachment: [:blob]])
          .order(:created_at)
        render json: journeys, meta: {total: journeys.size}
      end

      def show
        journey = Journey.find params[:id]
        render json: journey, include: [:journey_steps]
      end
    end
  end
end
