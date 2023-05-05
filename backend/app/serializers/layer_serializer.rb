# == Schema Information
#
# Table name: layers
#
#  id                        :bigint           not null, primary key
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
#  interaction_config        :text
#  timeline                  :boolean          default(FALSE)
#  timeline_steps            :date             default([]), is an Array
#  timeline_start_date       :date
#  timeline_end_date         :date
#  timeline_default_date     :date
#  timeline_period           :string
#  timeline_format           :string           default("%m/%d/%Y")
#  analysis_type             :string
#  name                      :string
#  info                      :text
#  legend                    :text
#  title                     :string
#  data_units                :string
#  processing                :string
#  description               :text
#  analysis_text_template    :text
#

class LayerSerializer < ActiveModel::Serializer
  cache key: "layer_#{I18n.locale}"
  attributes :name, :description, :slug, :layer_type, :zindex, :opacity, :active, :order,
    :dashboard_order, :color, :info, :interactivity, :css, :query, :layer_config, :layer_provider,
    :published, :locate_layer, :icon_class, :legend, :zoom_max, :zoom_min, :download,
    :dataset_shortname, :dataset_source_url, :analysis_suitable, :analysis_query, :analysis_body,
    :analysis_type, :analysis_text_template, :interaction_config, :timeline, :timeline_steps, :timeline_start_date,
    :timeline_end_date, :timeline_default_date, :timeline_period, :timeline_format
  has_one :layer_group, serializer: LayerGroupSerializer
  has_many :sources, each_serializer: SourceSerializer
  has_one :agrupation

  def type
    "layers"
  end

  def sources
    object.sources
  end

  def layer_group
    object.layer_groups.where(site_scope_id: instance_options[:site_scope]).first
  end

  def agrupation
    return if layer_group.blank?
    object.agrupations.where(layer_id: object.id, layer_group_id: layer_group.id).first
  end

  def timeline_steps
    Array.wrap(object.timeline_steps).sort
  end
end
