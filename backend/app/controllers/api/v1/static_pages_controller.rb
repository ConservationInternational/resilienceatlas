module Api
  module V1
    class StaticPagesController < ApiController
      def show
        static_page = StaticPage::Base.find_by! slug: params[:id]
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: static_page,
          serializer: StaticPageSerializer,
          include: %w[sections sections.section_items sections.section_paragraph sections.section_references]
      end
    end
  end
end
