# == Schema Information
#
# Table name: layers
#
#  id             :integer          not null, primary key
#  layer_group_id :integer
#  name           :string           not null
#  slug           :string           not null
#  layer_type     :string
#  zindex         :integer
#  active         :boolean
#  order          :integer
#  color          :string
#  info           :text
#  layer_provider :string
#  css            :text
#  interactivity  :text
#  opacity        :float
#  query          :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  locate_layer   :boolean          default(FALSE)
#  icon_class     :string
#  published      :boolean          default(TRUE)
#  legend         :text
#

class LayerSerializer < ActiveModel::Serializer
  cache key: "layer"
  attributes :name, :slug, :layer_type, :zindex, :opacity, :active, :order, :color, :info, :interactivity, :css, :query, :layer_provider, :published, :locate_layer, :icon_class, :legend
  has_one :layer_group, serializer: LayerGroupSerializer
  # has_many :layer_groups, serializer: LayerGroupSerializer
  def type
    'layers'
  end
  # def layer_groups
  #   LayerGroup.all
  # end
end
