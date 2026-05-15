# == Schema Information
#
# Table name: site_scopes
#
#  id               :bigint           not null, primary key
#  name             :string
#  color            :string
#  subdomain        :string
#  has_analysis     :boolean          default(FALSE)
#  latitude         :float
#  longitude        :float
#  header_theme     :string
#  zoom_level       :integer          default(3)
#  linkback_text    :text
#  linkback_url     :text
#  header_color     :string
#  logo_url         :text
#  predictive_model :boolean          default(FALSE), not null
#  analysis_options :boolean          default(FALSE), not null
#  has_gef_logo     :boolean
#  password_protected :boolean        default(FALSE), not null
#  username         :string
#  encrypted_password :string
#

class SiteScopeSerializer < ActiveModel::Serializer
  # NOTE: Do not use AMS cache here. AMS 0.10.x uses object.cache_key (without version)
  # which doesn't invalidate when the record is updated in Rails 7.2+. This caused
  # password_protected changes to be invisible until cache expiry or process restart.
  attributes :id, :name, :color, :subdomain, :has_analysis, :has_search, :latitude,
    :longitude, :header_theme, :zoom_level, :linkback_text, :linkback_url,
    :header_color, :logo_url, :favicon_url, :predictive_model, :analysis_options, :has_gef_logo,
    :password_protected, :linkback_text_color, :logo_urls
  has_many :site_pages

  def logo_urls
    [
      object.logo_url,
      object.logo_url_2,
      object.logo_url_3,
      object.logo_url_4,
      object.logo_url_5
    ].select(&:present?).first(5)
  end
end
