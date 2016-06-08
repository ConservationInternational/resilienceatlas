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
#  header_color :string
#

class SiteScopeSerializer < ActiveModel::Serializer
  attributes :id, :name, :color, :header_color, :subdomain, :has_analysis
  has_many :site_pages
end
