module Api
  module V1
    class HomepagesController < ApiController
      include SitesFilters

      def show
        homepage = Homepage.find_by! site_scope_id: params[:site_scope]
        # SitesFilters#check_site_scope_authentication replaces this with no_store for protected scopes.
        expires_in 1.hour, public: true, stale_while_revalidate: 5.minutes unless @site_scope&.requires_authentication?
        render json: homepage, include: [:homepage_journey, :homepage_sections]
      end
    end
  end
end
