module Api
  module V1
    class CategoriesController < ApiController
      def index
        # TODO - Use strong params when arranged which to use
        @categories = Category.fetch_all(params).includes(indicators: :translations)
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: @categories,
          meta: {total_categories: @categories.size},
          include: [:indicators]
      end
    end
  end
end
