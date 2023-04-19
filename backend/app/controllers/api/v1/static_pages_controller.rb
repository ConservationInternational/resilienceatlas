module Api
  module V1
    class StaticPagesController < ApiController
      def show
        static_page = StaticPage::Base.find_by! slug: params[:id]
        render json: static_page,
          serializer: StaticPageSerializer,
          include: %w[sections sections.section_items sections.section_paragraph sections.section_references]
      end
    end
  end
end
