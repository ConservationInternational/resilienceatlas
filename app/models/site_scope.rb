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

class SiteScope < ActiveRecord::Base
  has_many :layer_groups
  has_many :site_pages
  validates_presence_of :name, :header_theme
  def location
    [:latitude, :longitude]
  end
end
