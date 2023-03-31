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
#

class SiteScope < ApplicationRecord
  has_many :layer_groups
  has_many :site_pages

  translates :name, :linkback_text, fallbacks_for_empty_translations: true
  active_admin_translates :name, :linkback_text

  def location
    [:latitude, :longitude]
  end

  def clone!
    new_site_scope = SiteScope.new
    new_site_scope.assign_attributes attributes.except("id")
    translations.each { |t| new_site_scope.translations.build t.attributes.except("id") }
    new_site_scope.name = "#{name} _copy_ #{DateTime.now}"
    new_site_scope.save!
    new_site_scope
  end
end
