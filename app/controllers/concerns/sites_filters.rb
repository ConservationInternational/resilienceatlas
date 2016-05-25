module SitesFilters
  extend ActiveSupport::Concern
  included do
    before_action :set_site
  end
  private
  def layers_params
    params.permit(:site_scope)
  end
  def set_site
    site_scope = SiteScope.find_by(subdomain: 'tanzania') || SiteScope.find(1)
    params.merge!({site_scope: site_scope, site_scope_name: site_scope.name, site_scope_color: site_scope.color, site_scope_subdomain:site_scope.subdomain, site_scope_has_analysis: site_scope.has_analysis})
    params
  end
end
