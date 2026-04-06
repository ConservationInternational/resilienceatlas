module Api
  module V1
    class SitesController < ApiController
      include SitesFilters

      # Skip site scope authentication for site loading - we need to return the site data
      # including password_protected flag so the frontend can trigger the auth modal
      skip_before_action :check_site_scope_authentication, only: [:show, :index]

      def index
        sites = SiteScope.with_translations
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: sites
      end

      skip_before_action :authenticate_request, raise: false

      def show
        site = SiteScope.find(params[:site_scope])
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes
        render json: site, include: ["site_pages"]
      end
    end
  end
end
