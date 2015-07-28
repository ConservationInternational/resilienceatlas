# == Schema Information
#
# Table name: layers
#
#  id             :integer          not null, primary key
#  group_id       :integer
#  name           :string           not null
#  slug           :string           not null
#  layer_type     :string
#  zindex         :integer
#  active         :boolean
#  order          :integer
#  color          :string
#  info           :text
#  interactivity  :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  opacity        :float
#  query          :text
#  css            :text
#  layer_provider :string
#

class LayerSerializer < ActiveModel::Serializer
  cache key: "layer"
  attributes :name, :slug, :layer_type, :zindex, :opacity, :active, :order, :color, :info, :interactivity, :css, :query, :layer_provider
  has_one :layer_group, serializer: LayerGroupSerializer
  def type
    'layers'
  end
end
