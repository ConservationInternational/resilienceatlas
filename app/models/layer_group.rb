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
#  layer_group_id   :bigint           not null
#  name             :string
#  info             :text
#

class LayerGroup < ApplicationRecord
  has_many :agrupations
  has_many :layers, through: :agrupations
  belongs_to :super_group, class_name: "LayerGroup"
  has_many :sub_groups, class_name: "LayerGroup", foreign_key: :super_group_id, dependent: :nullify
  belongs_to :site_scope
  accepts_nested_attributes_for :agrupations, allow_destroy: true

  translates :name, :info
  active_admin_translates :name, :info

  validate :avoid_recursivity, on: :update
  validate :site_scope

  scope :site, ->(site) { where(site_scope_id: site) }

  def avoid_recursivity
    errors.add(:super_group, "This group can't be super group of itself.") if super_group_id.present? && super_group_id == id
  end

  def site_scope
    errors.add(:super_group, "Super group and group must be into the same site scope.") if super_group.present? && super_group.site_scope_id != site_scope_id
  end

  def self.fetch_all(options = {})
    site_scope = if options[:site_scope]
      options[:site_scope].to_i
    else
      1
    end
    layer_groups = LayerGroup.with_translations(I18n.locale)
    layer_groups.site(site_scope)
  end

  def clone!
    l_g = clone
    new_layer_group = LayerGroup.new(l_g.attributes.except("id"))
    new_layer_group.name = "#{name} _copy_ #{DateTime.now}"
    layers.each do |layer|
      new_layer_group.agrupations.new(layer_id: layer.id)
    end
    new_layer_group.save!
    new_layer_group
  end
end
