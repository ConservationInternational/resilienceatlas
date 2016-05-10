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
      when "atlas.tanzania"
        site_scope="3"
      when "atlas.ghana"
        site_scope="4"
      when "atlas.uganda"
        site_scope="5"
      when "atlas.rwanda"
        site_scope="6"
      when "amazonia"
          site_scope="7"
      when "test"
        site_scope="8"
      else
        site_scope="1"
    end
    params.merge!({site_scope: site_scope})
    params
  end
end
