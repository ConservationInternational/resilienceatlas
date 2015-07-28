# == Schema Information
#
# Table name: layer_groups
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
  cache key: "layer_group"
  attributes :name, :slug, :category, :active, :order, :info, :layer_group_type, :super_group_id, :super_group_name
  has_one :super_group, serializer: LayerGroupSerializer, include: true
  def type
    'layer_groups'
  end
  def super_group_name
    object.super_group.name
  end
end
