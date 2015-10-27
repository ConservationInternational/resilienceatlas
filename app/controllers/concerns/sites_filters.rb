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
    case request.subdomain.downcase
      when "indicators"
        site_scope="2"
      when "indicators.tanzania"
        site_scope="3"
      when "indicators.ghana"
        site_scope="4"
      when "indicators.uganda"
        site_scope="5"
      when "indicators.rwanda"
        site_scope="6"
      else
        site_scope="1"
    end
    params.merge!({site_scope: site_scope})
    params
  end
end
