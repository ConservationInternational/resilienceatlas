#!/usr/bin/env python3
"""
Script to generate layers.rb from the local PostgreSQL database.
Connects to localhost:5432/cigrp and extracts data for site_scope_id=1.
"""

import psycopg2
import json
import re
from datetime import date

def escape_ruby_string(s):
    """Escape a string for Ruby double-quoted string literal."""
    if s is None:
        return "nil"
    s = str(s)
    s = s.replace("\\", "\\\\")
    s = s.replace('"', '\\"')
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "\\r")
    return f'"{s}"'

def format_ruby_value(val):
    """Format a Python value as a Ruby literal."""
    if val is None:
        return "nil"
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, dict):
        return json.dumps(val).replace('"', "'")
    if isinstance(val, list):
        return repr(val)
    return escape_ruby_string(val)

def main():
    conn = psycopg2.connect(
        host="localhost",
        port=5432,
        dbname="cigrp",
        user="postgres",
        password=""  # Assuming no password or Windows auth
    )
    cur = conn.cursor()
    
    output = []
    output.append("# frozen_string_literal: true")
    output.append("")
    output.append(f"# Generated from production database on {date.today()}")
    output.append("# Only includes data for site_scope_id = 1 (main Resilience Atlas site)")
    output.append("")
    output.append('puts "Creating SiteScope..."')
    output.append("")
    
    # Get site scope
    cur.execute("""
        SELECT id, color, subdomain, has_analysis, latitude, longitude, 
               header_theme, zoom_level, linkback_url, header_color, 
               logo_url, predictive_model, analysis_options, has_gef_logo
        FROM site_scopes WHERE id = 1
    """)
    ss = cur.fetchone()
    if ss:
        output.append("SiteScope.find_or_create_by!(id: 1) do |ss|")
        output.append(f"  ss.color = {escape_ruby_string(ss[1])}")
        output.append(f"  ss.subdomain = {format_ruby_value(ss[2])}")
        output.append(f"  ss.has_analysis = {format_ruby_value(ss[3])}")
        output.append(f"  ss.latitude = {format_ruby_value(ss[4])}")
        output.append(f"  ss.longitude = {format_ruby_value(ss[5])}")
        output.append(f"  ss.header_theme = {escape_ruby_string(ss[6])}")
        output.append(f"  ss.zoom_level = {format_ruby_value(ss[7])}")
        output.append(f"  ss.linkback_url = {format_ruby_value(ss[8])}")
        output.append(f"  ss.header_color = {format_ruby_value(ss[9])}")
        output.append(f"  ss.logo_url = {format_ruby_value(ss[10])}")
        output.append(f"  ss.predictive_model = {format_ruby_value(ss[11])}")
        output.append(f"  ss.analysis_options = {format_ruby_value(ss[12])}")
        output.append(f"  ss.has_gef_logo = {format_ruby_value(ss[13])}")
        output.append("end")
    output.append("")
    
    # Get site scope translation
    cur.execute("""
        SELECT name, linkback_text FROM site_scope_translations 
        WHERE site_scope_id = 1 AND locale = 'en'
    """)
    ss_trans = cur.fetchone()
    if ss_trans:
        output.append("SiteScope.find(1).update!(")
        output.append(f"  name: {escape_ruby_string(ss_trans[0])}")
        output.append(")")
    output.append("")
    
    # Get layer groups for site_scope_id = 1
    output.append('puts "Creating LayerGroups..."')
    output.append("layer_groups = {}")
    output.append("")
    
    cur.execute("""
        SELECT lg.id, lg.super_group_id, lg.slug, lg.layer_group_type, lg.category,
               lg.active, lg.order, lg.icon_class, lg.site_scope_id,
               COALESCE(t.name, lg.slug) as name, t.info
        FROM layer_groups lg
        LEFT JOIN layer_group_translations t ON t.layer_group_id = lg.id AND t.locale = 'en'
        WHERE lg.site_scope_id = 1
        ORDER BY lg.id
    """)
    layer_groups = cur.fetchall()
    layer_group_ids = []
    
    for lg in layer_groups:
        lg_id = lg[0]
        layer_group_ids.append(lg_id)
        name = lg[9] or lg[2]  # name or slug
        info = lg[10] or ""
        
        output.append(f"layer_groups[{lg_id}] = LayerGroup.find_or_create_by!(id: {lg_id}) do |lg|")
        output.append(f"  lg.super_group_id = {format_ruby_value(lg[1])}")
        output.append(f"  lg.slug = {escape_ruby_string(lg[2])}")
        output.append(f"  lg.layer_group_type = {escape_ruby_string(lg[3])}")
        output.append(f"  lg.category = {escape_ruby_string(lg[4])}")
        output.append(f"  lg.active = {format_ruby_value(lg[5])}")
        output.append(f"  lg.order = {format_ruby_value(lg[6])}")
        output.append(f"  lg.icon_class = {escape_ruby_string(lg[7])}")
        output.append(f"  lg.site_scope_id = {format_ruby_value(lg[8])}")
        output.append(f"  lg.name = {escape_ruby_string(name)}")
        output.append(f"  lg.info = {escape_ruby_string(info)}")
        output.append("end")
        output.append("")
    
    # Get layers linked to these layer groups via agrupations
    output.append("")
    output.append('puts "Creating Layers..."')
    output.append("layers = {}")
    output.append("")
    
    if layer_group_ids:
        placeholders = ",".join(["%s"] * len(layer_group_ids))
        cur.execute(f"""
            SELECT DISTINCT l.id, l.layer_group_id, l.slug, l.layer_type, l.zindex, l.active,
                   l.order, l.color, l.layer_provider, l.css, l.interactivity, l.opacity,
                   l.query, l.locate_layer, l.icon_class, l.published, l.zoom_max, l.zoom_min,
                   l.dashboard_order, l.download, l.dataset_shortname, l.dataset_source_url,
                   l.title, l.start_date, l.end_date, l.spatial_resolution, l.spatial_resolution_units,
                   l.temporal_resolution, l.temporal_resolution_units, l.update_frequency,
                   l.version, l.analysis_suitable, l.analysis_query, l.layer_config,
                   l.analysis_body, l.interaction_config, l.timeline, l.timeline_steps,
                   l.timeline_start_date, l.timeline_end_date, l.timeline_default_date,
                   l.timeline_period, l.analysis_type,
                   COALESCE(t.name, l.slug) as trans_name, t.info, t.legend, t.description,
                   t.data_units, t.processing
            FROM layers l
            INNER JOIN agrupations a ON a.layer_id = l.id
            LEFT JOIN layer_translations t ON t.layer_id = l.id AND t.locale = 'en'
            WHERE a.layer_group_id IN ({placeholders})
            ORDER BY l.id
        """, layer_group_ids)
        
        layers = cur.fetchall()
        
        for layer in layers:
            l_id = layer[0]
            name = layer[43] or layer[2]  # trans_name or slug
            info = layer[44] or ""
            legend = layer[45] or ""
            description = layer[46]
            data_units = layer[47]
            processing = layer[48]
            
            # Generate slug from name if empty - slug is required
            slug = layer[2]
            if not slug:
                # Generate slug from name: lowercase, replace spaces with hyphens, keep only alphanumeric and hyphens
                import re
                slug_from_name = (name or f"layer-{l_id}").lower()
                slug_from_name = re.sub(r'[^a-z0-9\s-]', '', slug_from_name)
                slug_from_name = re.sub(r'[\s_]+', '-', slug_from_name)
                slug_from_name = re.sub(r'-+', '-', slug_from_name).strip('-')
                slug = slug_from_name or f"layer-{l_id}"
            
            # Handle layer_config specially - it might be JSON
            layer_config = layer[33]
            if layer_config:
                if isinstance(layer_config, dict):
                    layer_config_str = json.dumps(layer_config)
                else:
                    layer_config_str = str(layer_config)
                layer_config_formatted = f'"{layer_config_str.replace(chr(92), chr(92)+chr(92)).replace(chr(34), chr(92)+chr(34))}"'
            else:
                layer_config_formatted = "nil"
            
            output.append(f"layers[{l_id}] = Layer.find_or_create_by!(id: {l_id}) do |l|")
            output.append(f"  l.layer_group_id = {format_ruby_value(layer[1])}")
            output.append(f"  l.slug = {escape_ruby_string(slug)}")
            output.append(f"  l.layer_type = {escape_ruby_string(layer[3])}")
            output.append(f"  l.zindex = {format_ruby_value(layer[4])}")
            output.append(f"  l.active = {format_ruby_value(layer[5])}")
            output.append(f"  l.order = {format_ruby_value(layer[6])}")
            output.append(f"  l.color = {escape_ruby_string(layer[7])}")
            output.append(f"  l.layer_provider = {escape_ruby_string(layer[8])}")
            output.append(f"  l.css = {escape_ruby_string(layer[9])}")
            output.append(f"  l.interactivity = {escape_ruby_string(layer[10])}")
            output.append(f"  l.opacity = {format_ruby_value(layer[11])}")
            output.append(f"  l.query = {escape_ruby_string(layer[12])}")
            output.append(f"  l.locate_layer = {format_ruby_value(layer[13])}")
            output.append(f"  l.icon_class = {escape_ruby_string(layer[14])}")
            output.append(f"  l.published = {format_ruby_value(layer[15])}")
            output.append(f"  l.zoom_max = {format_ruby_value(layer[16])}")
            output.append(f"  l.zoom_min = {format_ruby_value(layer[17])}")
            output.append(f"  l.dashboard_order = {format_ruby_value(layer[18])}")
            output.append(f"  l.download = {format_ruby_value(layer[19])}")
            output.append(f"  l.dataset_shortname = {format_ruby_value(layer[20])}")
            output.append(f"  l.dataset_source_url = {format_ruby_value(layer[21])}")
            output.append(f"  l.title = {format_ruby_value(layer[22])}")
            output.append(f"  l.start_date = {format_ruby_value(layer[23])}")
            output.append(f"  l.end_date = {format_ruby_value(layer[24])}")
            output.append(f"  l.spatial_resolution = {format_ruby_value(layer[25])}")
            output.append(f"  l.spatial_resolution_units = {format_ruby_value(layer[26])}")
            output.append(f"  l.temporal_resolution = {format_ruby_value(layer[27])}")
            output.append(f"  l.temporal_resolution_units = {format_ruby_value(layer[28])}")
            output.append(f"  l.update_frequency = {format_ruby_value(layer[29])}")
            output.append(f"  l.version = {format_ruby_value(layer[30])}")
            output.append(f"  l.analysis_suitable = {format_ruby_value(layer[31])}")
            output.append(f"  l.analysis_query = {format_ruby_value(layer[32])}")
            output.append(f"  l.layer_config = {layer_config_formatted}")
            output.append(f"  l.analysis_body = {format_ruby_value(layer[34])}")
            # interaction_config is required by validation - provide default if empty
            interaction_config = layer[35]
            if not interaction_config:
                interaction_config = '{"output":[]}'
            output.append(f"  l.interaction_config = {escape_ruby_string(interaction_config)}")
            output.append(f"  l.timeline = {format_ruby_value(layer[36])}")
            output.append(f"  l.timeline_steps = {format_ruby_value(layer[37])}")
            output.append(f"  l.timeline_start_date = {format_ruby_value(layer[38])}")
            output.append(f"  l.timeline_end_date = {format_ruby_value(layer[39])}")
            output.append(f"  l.timeline_default_date = {format_ruby_value(layer[40])}")
            output.append(f"  l.timeline_period = {escape_ruby_string(layer[41])}")
            output.append(f"  l.analysis_type = {escape_ruby_string(layer[42])}")
            # Include translated fields in the create block to avoid validation errors
            output.append(f"  l.name = {escape_ruby_string(name)}")
            output.append(f"  l.info = {escape_ruby_string(info)}")
            output.append(f"  l.legend = {escape_ruby_string(legend)}")
            output.append(f"  l.description = {format_ruby_value(description)}")
            output.append(f"  l.data_units = {format_ruby_value(data_units)}")
            output.append(f"  l.processing = {format_ruby_value(processing)}")
            output.append("end")
            output.append("")
    
    # Get agrupations
    output.append("")
    output.append('puts "Creating Agrupations..."')
    output.append("")
    
    if layer_group_ids:
        placeholders = ",".join(["%s"] * len(layer_group_ids))
        cur.execute(f"""
            SELECT layer_id, layer_group_id, active
            FROM agrupations
            WHERE layer_group_id IN ({placeholders})
            ORDER BY id
        """, layer_group_ids)
        
        agrupations = cur.fetchall()
        for agrup in agrupations:
            output.append(f"Agrupation.find_or_create_by!(layer_id: {agrup[0]}, layer_group_id: {agrup[1]}) do |a|")
            output.append(f"  a.active = {format_ruby_value(agrup[2])}")
            output.append("end")
        output.append("")
    
    output.append('puts "Seed data created successfully!"')
    output.append("")
    
    cur.close()
    conn.close()
    
    # Write to file - use absolute path
    import os
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "layers.rb")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(output))
    
    print(f"Generated {output_path} with {len(layer_groups)} layer groups and {len(layers) if layer_group_ids else 0} layers")

if __name__ == "__main__":
    main()
