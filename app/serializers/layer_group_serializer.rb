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

#  id               :integer          not null, primary key
#  name             :string
#  super_group_id   :integer
#  slug             :string
#  layer_group_type :string
#  category         :string
#  active           :boolean
#  order            :integer
#  info             :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class LayerGroupSerializer < ActiveModel::Serializer
  cache key: "layer_group_#{I18n.locale}"
  attributes :name, :slug, :category, :active, :order, :info, :layer_group_type, :super_group_id, :super_group_name, :icon_class
  has_one :super_group, serializer: LayerGroupSerializer, include: true
  def type
    "layer_groups"
  end

  def super_group_name
    object.super_group.name if object.super_group.present?
  end
end
