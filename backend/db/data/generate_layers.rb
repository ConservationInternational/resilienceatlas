#!/usr/bin/env ruby
# Script to generate layers.rb from the database
# Run this from within the Rails console or as a Rails task

require "json"

def escape_string(str)
  return "nil" if str.nil?
  str.to_s.gsub("\\", "\\\\\\\\").gsub('"', '\\"').gsub("\n", "\\n").gsub("\r", "\\r")
end

def quote_string(str)
  return "nil" if str.nil?
  "\"#{escape_string(str)}\""
end

def format_value(val)
  case val
  when nil
    "nil"
  when true
    "true"
  when false
    "false"
  when Integer, Float
    val.to_s
  when Array
    val.inspect
  when Hash
    val.to_json.inspect
  else
    quote_string(val.to_s)
  end
end

output = []

output << "# frozen_string_literal: true"
output << ""
output << "# Generated from production database on #{Time.now.strftime("%Y-%m-%d")}"
output << "# Only includes data for site_scope_id = 1 (main Resilience Atlas site)"
output << ""
output << 'puts "Creating SiteScope..."'
output << ""

# Get the main site scope
site_scope = SiteScope.find(1)
output << "SiteScope.find_or_create_by!(id: 1) do |ss|"
output << "  ss.color = #{quote_string(site_scope.color)}"
output << "  ss.subdomain = #{format_value(site_scope.subdomain)}"
output << "  ss.has_analysis = #{format_value(site_scope.has_analysis)}"
output << "  ss.latitude = #{format_value(site_scope.latitude)}"
output << "  ss.longitude = #{format_value(site_scope.longitude)}"
output << "  ss.header_theme = #{quote_string(site_scope.header_theme)}"
output << "  ss.zoom_level = #{format_value(site_scope.zoom_level)}"
output << "  ss.linkback_url = #{format_value(site_scope.linkback_url)}"
output << "  ss.header_color = #{format_value(site_scope.header_color)}"
output << "  ss.logo_url = #{format_value(site_scope.logo_url)}"
output << "  ss.predictive_model = #{format_value(site_scope.predictive_model)}"
output << "  ss.analysis_options = #{format_value(site_scope.analysis_options)}"
output << "  ss.has_gef_logo = #{format_value(site_scope.has_gef_logo)}"
output << "  ss.password_protected = #{format_value(site_scope.password_protected)}"
output << "end"
output << ""

output << 'puts "Creating LayerGroups..."'
output << "layer_groups = {}"
output << ""

# Get layer groups for site_scope 1
layer_groups = LayerGroup.where(site_scope_id: 1).order(:id)

layer_groups.each do |lg|
  # Get the English translation
  translation = lg.translations.find { |t| t.locale == "en" } || lg.translations.first
  name = translation&.name || lg.slug.titleize
  info = translation&.info || ""

  output << "layer_groups[#{lg.id}] = LayerGroup.find_or_create_by!(id: #{lg.id}) do |lg|"
  output << "  lg.super_group_id = #{format_value(lg.super_group_id)}"
  output << "  lg.slug = #{quote_string(lg.slug)}"
  output << "  lg.layer_group_type = #{quote_string(lg.layer_group_type)}"
  output << "  lg.category = #{quote_string(lg.category)}"
  output << "  lg.active = #{format_value(lg.active)}"
  output << "  lg.order = #{format_value(lg.order)}"
  output << "  lg.icon_class = #{format_value(lg.icon_class)}"
  output << "  lg.site_scope_id = 1"
  output << "  lg.name = #{quote_string(name)}"
  output << "  lg.info = #{quote_string(info)}"
  output << "end"
  output << ""
end

output << ""
output << 'puts "Creating Layers..."'
output << "layers = {}"
output << ""

# Get all layers that are linked to site_scope 1 layer_groups via agrupations
layer_group_ids = layer_groups.pluck(:id)
layer_ids = Agrupation.where(layer_group_id: layer_group_ids).pluck(:layer_id).uniq
layers = Layer.where(id: layer_ids).order(:id)

layers.each do |layer|
  # Get the English translation
  translation = layer.translations.find { |t| t.locale == "en" } || layer.translations.first
  name = translation&.name || layer.slug.titleize
  info = translation&.info || ""
  legend = translation&.legend || ""
  description = translation&.description
  data_units = translation&.data_units
  processing = translation&.processing

  output << "layers[#{layer.id}] = Layer.find_or_create_by!(id: #{layer.id}) do |l|"
  output << "  l.layer_group_id = #{format_value(layer.layer_group_id)}"
  output << "  l.slug = #{quote_string(layer.slug)}"
  output << "  l.layer_type = #{quote_string(layer.layer_type)}"
  output << "  l.zindex = #{format_value(layer.zindex)}"
  output << "  l.active = #{format_value(layer.active)}"
  output << "  l.order = #{format_value(layer.order)}"
  output << "  l.color = #{quote_string(layer.color)}"
  output << "  l.layer_provider = #{quote_string(layer.layer_provider)}"
  output << "  l.css = #{quote_string(layer.css)}"
  output << "  l.interactivity = #{quote_string(layer.interactivity)}"
  output << "  l.opacity = #{format_value(layer.opacity)}"
  output << "  l.query = #{quote_string(layer.query)}"
  output << "  l.locate_layer = #{format_value(layer.locate_layer)}"
  output << "  l.icon_class = #{quote_string(layer.icon_class)}"
  output << "  l.published = #{format_value(layer.published)}"
  output << "  l.zoom_max = #{format_value(layer.zoom_max)}"
  output << "  l.zoom_min = #{format_value(layer.zoom_min)}"
  output << "  l.dashboard_order = #{format_value(layer.dashboard_order)}"
  output << "  l.download = #{format_value(layer.download)}"
  output << "  l.dataset_shortname = #{format_value(layer.dataset_shortname)}"
  output << "  l.dataset_source_url = #{format_value(layer.dataset_source_url)}"
  output << "  l.title = #{format_value(layer.title)}"
  output << "  l.start_date = #{format_value(layer.start_date)}"
  output << "  l.end_date = #{format_value(layer.end_date)}"
  output << "  l.spatial_resolution = #{format_value(layer.spatial_resolution)}"
  output << "  l.spatial_resolution_units = #{format_value(layer.spatial_resolution_units)}"
  output << "  l.temporal_resolution = #{format_value(layer.temporal_resolution)}"
  output << "  l.temporal_resolution_units = #{format_value(layer.temporal_resolution_units)}"
  output << "  l.update_frequency = #{format_value(layer.update_frequency)}"
  output << "  l.version = #{format_value(layer.version)}"
  output << "  l.analysis_suitable = #{format_value(layer.analysis_suitable)}"
  output << "  l.analysis_query = #{format_value(layer.analysis_query)}"
  output << "  l.layer_config = #{format_value(layer.layer_config)}"
  output << "  l.analysis_body = #{format_value(layer.analysis_body)}"
  output << "  l.interaction_config = #{quote_string(layer.interaction_config)}"
  output << "  l.timeline = #{format_value(layer.timeline)}"
  output << "  l.timeline_steps = #{format_value(layer.timeline_steps)}"
  output << "  l.timeline_start_date = #{format_value(layer.timeline_start_date)}"
  output << "  l.timeline_end_date = #{format_value(layer.timeline_end_date)}"
  output << "  l.timeline_default_date = #{format_value(layer.timeline_default_date)}"
  output << "  l.timeline_period = #{quote_string(layer.timeline_period)}"
  output << "  l.analysis_type = #{quote_string(layer.analysis_type)}"
  # Include translation fields in the create block
  output << "  l.name = #{quote_string(name)}"
  output << "  l.info = #{quote_string(info)}"
  output << "  l.legend = #{quote_string(legend)}"
  output << "  l.description = #{format_value(description)}"
  output << "  l.data_units = #{format_value(data_units)}"
  output << "  l.processing = #{format_value(processing)}"
  output << "end"
  output << ""
end

output << ""
output << 'puts "Creating Agrupations..."'
output << ""

# Get agrupations linking layers to layer_groups
agrupations = Agrupation.where(layer_group_id: layer_group_ids).order(:id)

agrupations.each do |agrup|
  output << "Agrupation.find_or_create_by!(layer_id: #{agrup.layer_id}, layer_group_id: #{agrup.layer_group_id}) do |a|"
  output << "  a.active = #{format_value(agrup.active)}"
  output << "end"
end

output << ""
output << 'puts "Seed data created successfully!"'
output << ""

# Write to file
File.write(Rails.root.join("db/data/layers_generated.rb"), output.join("\n"))
puts "Generated layers_generated.rb"
