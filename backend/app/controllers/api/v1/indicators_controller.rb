module Api
  module V1
    class IndicatorsController < ApiController
      def index
        # TODO - Use strong params when arranged which to use
        @indicators = Indicator.fetch_all(params).includes(:category, models: :translations)
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: @indicators,
          meta: {total_indicators: @indicators.size},
          include: [:models, :category]
      end
    end
  end
end
