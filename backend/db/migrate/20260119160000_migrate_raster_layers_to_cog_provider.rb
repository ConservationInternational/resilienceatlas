# Migrate raster layers to use COG provider with TiTiler
#
# This migration converts all layers with layer_provider='raster' to use
# the 'cog' provider with TiTiler-based tile serving.
#
# The migration:
# 1. Extracts the table name from the query column
# 2. Parses the CSS to extract colormap (raster-colorizer-stops)
# 3. Stores COG source URL and colormap in layer_config
# 4. Updates layer_provider to 'cog'
#
# NOTE: The TiTiler base URL is NOT stored in the database. Instead, it is
# configured via the NEXT_PUBLIC_TITILER_URL environment variable in the
# frontend. This allows different environments (staging/production) to use
# different TiTiler instances.
#
class MigrateRasterLayersToCogProvider < ActiveRecord::Migration[7.2]
  COG_S3_BASE_URL = "https://resilienceatlas.s3.dualstack.us-east-1.amazonaws.com/cogs/".freeze

  def up
    # Find all raster layers - join with translations to get name for logging
    # Note: name is in layer_translations table, not layers table
    raster_layers = execute(<<-SQL.squish)
      SELECT l.id, l.slug, l.query, l.css, l.layer_config, lt.name
      FROM layers l
      LEFT JOIN layer_translations lt ON lt.layer_id = l.id AND lt.locale = 'en'
      WHERE l.layer_provider = 'raster'
    SQL

    raster_layers.each do |layer|
      layer_id = layer["id"]
      slug = layer["slug"]
      name = layer["name"] || slug
      query = layer["query"]
      css = layer["css"]

      begin
        # Extract table name from query
        table_name = extract_table_name(query)

        if table_name.nil?
          Rails.logger.warn "MigrateRasterLayersToCog: Could not extract table name for layer #{layer_id} (#{name}). Query: #{query}"
          next
        end

        # Parse CSS to extract colormap
        colormap = parse_css_colormap(css)

        # Build the layer_config
        layer_config = build_layer_config(table_name, colormap)

        # Update the layer
        execute(<<-SQL.squish)
          UPDATE layers
          SET layer_provider = 'cog',
              layer_config = #{connection.quote(layer_config.to_json)}
          WHERE id = #{layer_id}
        SQL

        Rails.logger.info "MigrateRasterLayersToCog: Successfully migrated layer #{layer_id} (#{name}) to COG provider with table #{table_name}"
      rescue => e
        Rails.logger.error "MigrateRasterLayersToCog: Failed to migrate layer #{layer_id} (#{name}): #{e.message}"
        raise e # Re-raise to rollback transaction
      end
    end
  end

  def down
    # This migration cannot be automatically reversed since we lose the original
    # raster configuration. However, we can mark layers back as raster.
    # We identify migrated layers by their layer_config containing the S3 COG URL pattern.
    execute(<<-SQL.squish)
      UPDATE layers
      SET layer_provider = 'raster'
      WHERE layer_provider = 'cog'
      AND layer_config LIKE '%resilienceatlas.s3.dualstack%'
      AND layer_config LIKE '%"source":%'
    SQL
  end

  private

  # Extract the table name from a CartoDB raster query
  # Handles various query formats:
  # - "select * from table_name"
  # - "select ... from table_name t, ..."
  # - "with geom as (...) select ... from table_name t, geom"
  def extract_table_name(query)
    return nil if query.blank?

    # Normalize the query
    normalized = query.gsub(/\s+/, " ").strip.downcase

    # Pattern 1: Simple "select * from table_name"
    if normalized =~ /select\s+\*\s+from\s+(\w+)/
      return $1
    end

    # Pattern 2: "select ... from table_name t, ..." (with alias)
    # Match the first table after FROM that's not a common keyword or subquery alias
    if normalized =~ /from\s+(\w+)(?:\s+[a-z])?(?:\s*,|\s+where|\s*$)/
      table = $1
      # Exclude common SQL keywords and subquery patterns
      return table unless %w[select with as where and or on join left right inner outer].include?(table)
    end

    # Pattern 3: Complex queries with WITH clause - look for the main table in the query
    # Example: "with geom as (...) select ... from hornofafrica_table t, geom"
    if normalized.include?("with")
      # Extract the part after the main SELECT's FROM
      if normalized =~ /\)\s*select[^)]+from\s+(\w+)/
        return $1
      end
    end

    # Pattern 4: st_clip or other function calls - extract the table from the function arguments
    # Example: "select st_clip(t.the_raster_webmercator,...) from table_name t, ..."
    if normalized =~ /from\s+(\w+)\s+t\s*[,\s]/
      return $1
    end

    # Fallback: Try to find any word after "from" that looks like a table name
    if normalized =~ /from\s+(\w+)/
      return $1
    end

    nil
  end

  # Parse CSS to extract colormap from raster-colorizer-stops
  # Returns a hash of { value => [r, g, b, a] }
  def parse_css_colormap(css)
    return {} if css.blank?

    colormap = {}

    # Match all stop() definitions
    # Format: stop(value,#hexcolor) or stop(value,transparent) or stop(value,#hexcolor,exact)
    css.scan(/stop\s*\(\s*(-?[\d.]+)\s*,\s*([^)]+)\s*\)/i).each do |match|
      value = match[0].to_f
      color_str = match[1].strip

      # Handle "transparent" as a special case
      if color_str.downcase.include?("transparent")
        # Skip transparent values - TiTiler handles nodata differently
        next
      end

      # Extract hex color (might have trailing options like ",exact")
      hex_match = color_str.match(/#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})/)
      next unless hex_match

      hex_color = hex_match[1]

      # Convert hex to RGBA array
      rgba = hex_to_rgba(hex_color)
      colormap[value.to_i] = rgba
    end

    colormap
  end

  # Convert hex color to RGBA array [r, g, b, a]
  def hex_to_rgba(hex)
    # Handle 3-digit hex
    if hex.length == 3
      hex = hex.chars.map { |c| c * 2 }.join
    end

    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    [r, g, b, 255] # Full opacity
  end

  # Build the layer_config JSON for a COG layer
  # NOTE: We store the COG source URL and colormap, NOT the full TiTiler URL.
  # The frontend constructs the TiTiler tile URL at runtime using the
  # NEXT_PUBLIC_TITILER_URL environment variable.
  def build_layer_config(table_name, colormap)
    cog_url = "#{COG_S3_BASE_URL}#{table_name}.tif"

    {
      type: "tileLayer",
      body: {
        # The source COG URL - frontend will construct TiTiler URL from this
        source: cog_url,
        # Colormap for the raster visualization
        colormap: colormap,
        # Options for Leaflet tileLayer
        options: {}
      }
    }
  end
end
