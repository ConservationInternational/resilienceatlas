module Api
  module V1
    class CategoriesController < ApiController
      include SitesFilters
      def index
        # TODO - Use strong params when arranged which to use
        @categories = Category.joins(indicators: {models: :site_scopes}).where(site_scopes: {id: @site_scope.id})
          .distinct.includes(indicators: :translations)
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: @categories,
          meta: {total_categories: @categories.size},
          include: [:indicators], site_scope: @site_scope.id
      end
    end
  end
end
