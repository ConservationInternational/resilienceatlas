module Api
  module V1
    class SitesController < ApiController
      include SitesFilters

      def index
        sites = SiteScope.all
        render json: sites
      end

      skip_before_action :authenticate_request, raise: false

      def show
        site = SiteScope.find(params[:site_scope])
        render json: site, include: ["site_pages"]
      end
    end
  end
end
