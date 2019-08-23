# == Schema Information
#
# Table name: layers
#
#  id                        :integer          not null, primary key
#  layer_group_id            :integer
#  slug                      :string           not null
#  layer_type                :string
#  zindex                    :integer
#  active                    :boolean
#  order                     :integer
#  color                     :string
#  layer_provider            :string
#  css                       :text
#  interactivity             :text
#  opacity                   :float
#  query                     :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  locate_layer              :boolean          default(FALSE)
#  icon_class                :string
#  published                 :boolean          default(TRUE)
#  zoom_max                  :integer          default(100)
#  zoom_min                  :integer          default(0)
#  dashboard_order           :integer
#  download                  :boolean          default(FALSE)
#  dataset_shortname         :string
#  dataset_source_url        :text
#  start_date                :datetime
#  end_date                  :datetime
#  spatial_resolution        :string
#  spatial_resolution_units  :string
#  temporal_resolution       :string
#  temporal_resolution_units :string
#  update_frequency          :string
#  version                   :string
#  analysis_suitable         :boolean          default(FALSE)
#  analysis_query            :text
#  layer_config              :text
#  analysis_body             :text
#

class LayerSerializer < ActiveModel::Serializer
  cache key: "layer_#{I18n.locale}"
  attributes :name, :slug, :layer_type, :zindex, :opacity, :active, :order,
             :dashboard_order, :color, :info, :interactivity, :css, :query, :layer_config, :layer_provider,
             :published, :locate_layer, :icon_class, :legend, :zoom_max, :zoom_min, :download,
             :dataset_shortname, :dataset_source_url, :analysis_suitable, :analysis_query, :analysis_body,
             :interaction_config
  has_one :layer_group, serializer: LayerGroupSerializer
  has_many :sources, each_serializer: SourceSerializer
  def type
    'layers'
  end
  def sources
    object.sources
  end
  def layer_group
    object.layer_groups.where(site_scope_id: options[:site_scope]).first
  end
end
