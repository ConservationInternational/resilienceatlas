module Api
  module V1
    class IndicatorsController < ApiController
      include SitesFilters
      def index
        # TODO - Use strong params when arranged which to use
        @indicators = Indicator.joins(models: :site_scopes).where(site_scopes: {id: @site_scope.id})
          .distinct.includes(:category, models: :translations)
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: @indicators,
          meta: {total_indicators: @indicators.size},
          include: [:models, :category], site_scope: @site_scope.id
      end
    end
  end
end
