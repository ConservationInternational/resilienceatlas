module SitesFilters
  extend ActiveSupport::Concern
  included do
    before_action :set_site
  end
  def set_site
    site_scope = SiteScope.find_by(subdomain: params[:site_scope]) || SiteScope.find_by(subdomain: request.subdomain.downcase) || SiteScope.find(1)
    params[:site_scope] = site_scope.id
    params
  end

  private

  def layers_params
    params.permit(:site_scope)
  end
end
