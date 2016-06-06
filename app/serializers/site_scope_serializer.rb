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

class SiteScopeSerializer < ActiveModel::Serializer
  attributes :id, :name, :color, :subdomain, :has_analysis
  has_many :site_pages
end
