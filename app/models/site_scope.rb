# == Schema Information
#
# Table name: site_scopes
#
#  id           :integer          not null, primary key
#  name         :string           default("global")
#  color        :string
#  subdomain    :string
#  has_analysis :boolean          default(FALSE)
#  latitude     :float
#  longitude    :float
#

class SiteScope < ActiveRecord::Base
  has_many :layer_groups
  has_many :site_pages
  def location
    [:latitude, :longitude]
  end
end
