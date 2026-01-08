module Api
  module V1
    class HomepagesController < ApiController
      include SitesFilters

      def show
        homepage = Homepage.find_by! site_scope_id: params[:site_scope]
        render json: homepage, include: [:homepage_journey, :homepage_sections]
      end
    end
  end
end
