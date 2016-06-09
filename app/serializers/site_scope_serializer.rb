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
#

class SiteScopeSerializer < ActiveModel::Serializer
  attributes :id, :name, :color, :subdomain, :has_analysis, :latitude, :longitude, :header_theme
  has_many :site_pages
end
