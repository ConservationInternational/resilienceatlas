module Api
  module V1
    class SitesController < ApiController
    include SitesFilters
      def show
        site = SiteScope.find(params[:site_scope])
        render json: site, include: ['site_pages']
      end
    end
  end
end
