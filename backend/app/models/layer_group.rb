# == Schema Information
#
# Table name: layer_groups
#
#  id               :bigint           not null, primary key
#  super_group_id   :integer
#  slug             :string
#  layer_group_type :string
#  category         :string
#  active           :boolean
#  order            :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  icon_class       :string
#  site_scope_id    :integer          default(1)
#  name             :string
#  info             :text
#

class LayerGroup < ApplicationRecord
  has_many :agrupations, dependent: :destroy
  has_many :layers, through: :agrupations
  belongs_to :super_group, class_name: "LayerGroup", optional: true
  has_many :sub_groups, class_name: "LayerGroup", foreign_key: :super_group_id, dependent: :nullify
  belongs_to :site_scope
  accepts_nested_attributes_for :agrupations, allow_destroy: true

  translates :name, :info, touch: true, fallbacks_for_empty_translations: true
  active_admin_translates :name, :info

  validate :avoid_recursivity, on: :update
  validate :super_group_scope

  scope :site, ->(site) { where(site_scope_id: site) }

  def avoid_recursivity
    errors.add(:super_group, "This group can't be super group of itself.") if super_group_id.present? && super_group_id == id
  end

  def super_group_scope
    errors.add(:super_group, "Super group and group must be into the same site scope.") if super_group.present? && super_group.site_scope_id != site_scope_id
  end

  def self.fetch_all(options = {})
    site_scope = if options[:site_scope]
      options[:site_scope].to_i
    else
      1
    end
    layer_groups = LayerGroup.with_translations
    layer_groups.site(site_scope)
  end

  def clone!
    new_layer_group = LayerGroup.new
    new_layer_group.assign_attributes attributes.except("id")
    translations.each { |t| new_layer_group.translations.build t.attributes.except("id") }
    agrupations.each { |a| new_layer_group.agrupations.build a.attributes.except("id") }
    new_layer_group.name = "#{name} _copy_ #{DateTime.now}"
    new_layer_group.save!
    new_layer_group
  end
end
