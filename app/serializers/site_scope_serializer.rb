# == Schema Information
#
# Table name: site_scopes
#
#  id           :integer          not null, primary key
#  name         :string
#  color        :string
#  subdomain    :string
#  has_analysis :boolean          default(FALSE)
#  latitude     :float
#  longitude    :float
#  header_theme :string
#  zoom_level   :integer          default(3)
#

class SiteScopeSerializer < ActiveModel::Serializer
  attributes :id, :name, :color, :subdomain, :has_analysis, :latitude, :longitude, :header_theme, :zoom_level
  has_many :site_pages
end
