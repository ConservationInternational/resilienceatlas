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
#  analytics_code   :string
#  has_gef_logo     :boolean
#

class SiteScopeSerializer < ActiveModel::Serializer
  attributes :id, :name, :color, :subdomain, :has_analysis, :latitude,
    :longitude, :header_theme, :zoom_level, :linkback_text, :linkback_url,
    :header_color, :logo_url, :predictive_model, :analysis_options, :analytics_code,
    :has_gef_logo
  has_many :site_pages
end
