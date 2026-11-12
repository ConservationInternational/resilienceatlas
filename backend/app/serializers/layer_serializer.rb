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
  attributes :name, :description, :slug, :layer_type, :zindex, :opacity, :active, :order,
    :dashboard_order, :color, :info, :css, :query, :layer_config, :layer_provider,
    :published, :locate_layer, :icon_class, :legend, :zoom_max, :zoom_min, :download,
    :dataset_shortname, :dataset_source_url, :analysis_suitable, :analysis_query, :analysis_body,
    :analysis_type, :analysis_text_template, :interaction_config, :timeline, :timeline_steps, :timeline_start_date,
    :timeline_end_date, :timeline_default_date, :timeline_period
  has_one :layer_group, serializer: LayerGroupSerializer
  has_many :sources, each_serializer: SourceSerializer
  has_one :agrupation

  def type
    "layers"
  end

  def layer_group
    object.layer_groups.find { |r| r.site_scope_id == instance_options[:site_scope] }
  end

  def agrupation
    return if layer_group.blank?
    object.agrupations.find { |r| r.layer_id == object.id && r.layer_group_id == layer_group.id }
  end

  def layer_config
    raw = object.layer_config
    return raw unless %w[martin cog gee arcgis_feature].include?(object.layer_provider)

    begin
      config = JSON.parse(raw || "{}")
    rescue JSON::ParserError
      Rails.logger.error "[LayerSerializer] Invalid ArcGIS configuration for layer #{object.id}"
      return "{}"
    end

    config["body"] ||= {} if object.layer_provider == "gee"
    body = config["body"].is_a?(Hash) ? config["body"] : config
    return raw unless body.is_a?(Hash)

    if %w[martin cog gee].include?(object.layer_provider) &&
        object.respond_to?(:tile_cache_version) &&
        TileSecurityPolicy.new(object).public_cache_eligible? &&
        TileRendererService.public_representation_valid?(object)
      cog_sources = (object.layer_provider == "cog") ? LayerDataSources.cog_urls(object) : []
      has_timeline_source = cog_sources.any? &&
        cog_sources.all? { |source| source.match?(/\{\{(?:year|month|day)\}\}/) }
      time_variant = (object.timeline? && has_timeline_source) ? "?time={{year}}-{{month}}-{{day}}" : ""
      route = "/api/public-tiles/#{object.id}/#{object.tile_cache_version}/{z}/{x}/{y}#{time_variant}"
      body["public_tile_url"] = tile_public_url(route)
    else
      body.delete("public_tile_url")
    end

    if object.layer_provider == "gee"
      body["url"] = "/api/earth-engine/tiles/#{object.id}/{z}/{x}/{y}"
      return config.to_json
    end

    return config.to_json unless object.layer_provider == "arcgis_feature" && body["token"].present?

    body.delete("token")
    body["useProxy"] = true
    config.to_json
  end

  def analysis_query
    return object.analysis_query unless object.layer_provider == "gee" && object.analysis_query.present?

    "/api/earth-engine/histogram?layer_id=#{object.id}"
  end

  def interaction_config
    return object.interaction_config unless object.layer_provider == "gee"

    config = JSON.parse(object.interaction_config.presence || "{}")
    if config.dig("config", "url").present?
      query = config["config"]["url"].split("?", 2).last
      config["config"]["url"] = "/api/earth-engine/raster?layer_id=#{object.id}&#{query}"
    end
    config.to_json
  end

  def timeline_steps
    Array.wrap(object.timeline_steps).sort
  end

  private

  def tile_public_url(route)
    origin = ENV["TILE_PUBLIC_CDN_URL"].presence
    return route unless origin

    uri = URI.parse(origin)
    return route unless uri.is_a?(URI::HTTPS) && uri.port == 443 &&
      uri.path.in?(["", "/"]) && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?

    "#{uri.scheme}://#{uri.host}#{route}"
  rescue URI::InvalidURIError
    route
  end
end
