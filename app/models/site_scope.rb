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

class SiteScope < ApplicationRecord
  has_many :layer_groups
  has_many :site_pages
  # validates_presence_of :name, :header_theme
  def location
    [:latitude, :longitude]
  end

  scope :by_keyword, -> (keyword) { where("name ILIKE ?", "%#{keyword}%") }

  def clone!
    site_scope = self.clone
    new_site_scope = SiteScope.new(site_scope.attributes.except("id"))
    new_site_scope.name = "#{self.name} _copy_ #{DateTime.now}"    
    new_site_scope.save!
    return new_site_scope
  end

end
