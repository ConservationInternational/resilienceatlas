module Api
  module V1
    class IndicatorsController < ApiController

      def index
        # TODO - Use strong params when arranged which to use
        @indicators = Indicator.fetch_all(params)
        render json: @indicators,
               meta: { total_indicators: @indicators.size },
               include: [:models]
      end
    end
  end
end
