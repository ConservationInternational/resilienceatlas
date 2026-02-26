# Update existing COG layers to use source-based configuration
#
# This migration converts COG layers that have hardcoded TiTiler URLs in their
# layer_config to the new format that stores only the COG source URL and colormap.
#
# The new format allows the frontend to construct the TiTiler URL at runtime
# using the NEXT_PUBLIC_TITILER_URL environment variable, enabling different
# environments (staging/production) to use different TiTiler instances.
#
# Old format:
#   {
#     "type": "tileLayer",
#     "body": {
#       "url": "https://titiler.example.org/tiles/WebMercatorQuad/{z}/{x}/{y}?url=...&colormap={{colormap}}"
#     },
#     "params": { "colormap": {...} }
#   }
#
# New format:
#   {
#     "type": "tileLayer",
#     "body": {
#       "source": "https://resilienceatlas.s3.dualstack.us-east-1.amazonaws.com/cogs/layer.tif",
#       "colormap": {...},
#       "options": {}
#     }
#   }
#
class UpdateCogLayersToSourceFormat < ActiveRecord::Migration[7.2]
  def up
    # Find all COG layers that have the old URL-based format
    # They have body.url but not body.source
    cog_layers = execute(<<-SQL.squish)
      SELECT l.id, l.slug, l.layer_config, lt.name
      FROM layers l
      LEFT JOIN layer_translations lt ON lt.layer_id = l.id AND lt.locale = 'en'
      WHERE l.layer_provider = 'cog'
      AND l.layer_config LIKE '%"url":%'
      AND l.layer_config NOT LIKE '%"source":%'
    SQL

    updated_count = 0

    cog_layers.each do |layer|
      layer_id = layer["id"]
      slug = layer["slug"]
      name = layer["name"] || slug
      layer_config_json = layer["layer_config"]

      begin
        config = JSON.parse(layer_config_json)

        # Extract the COG URL from the TiTiler tile URL
        tile_url = config.dig("body", "url")
        next unless tile_url

        # Extract the COG source URL from the 'url' query parameter
        cog_url = extract_cog_url_from_tile_url(tile_url)
        next unless cog_url

        # Get colormap from params or empty hash
        colormap = config.dig("params", "colormap") || {}

        # Build new layer_config
        new_config = {
          type: "tileLayer",
          body: {
            source: cog_url,
            colormap: colormap,
            options: config.dig("body", "options") || {}
          }
        }

        # Update the layer
        execute(<<-SQL.squish)
          UPDATE layers
          SET layer_config = #{connection.quote(new_config.to_json)}
          WHERE id = #{layer_id}
        SQL

        updated_count += 1
        Rails.logger.info "UpdateCogLayersToSourceFormat: Updated layer #{layer_id} (#{name}) to source format"
      rescue JSON::ParserError => e
        Rails.logger.warn "UpdateCogLayersToSourceFormat: Could not parse layer_config for layer #{layer_id}: #{e.message}"
      rescue => e
        Rails.logger.error "UpdateCogLayersToSourceFormat: Failed to update layer #{layer_id} (#{name}): #{e.message}"
        raise e
      end
    end

    Rails.logger.info "UpdateCogLayersToSourceFormat: Updated #{updated_count} COG layers to source format"
  end

  def down
    # This migration cannot be automatically reversed since we would need
    # to know which TiTiler URL was originally used
    Rails.logger.warn "UpdateCogLayersToSourceFormat: Rollback not supported - layers must be manually updated"
  end

  private

  # Extract the COG source URL from a TiTiler tile URL
  # Example input: https://titiler.example.org/tiles/WebMercatorQuad/{z}/{x}/{y}?url=https%3A%2F%2Fbucket.s3.amazonaws.com%2Ffile.tif&colormap=...
  # Example output: https://bucket.s3.amazonaws.com/file.tif
  def extract_cog_url_from_tile_url(tile_url)
    return nil if tile_url.blank?

    # Extract the 'url' query parameter
    url_match = tile_url.match(/[?&]url=([^&]+)/)
    return nil unless url_match

    # URL decode the COG URL
    CGI.unescape(url_match[1])
  rescue => e
    Rails.logger.warn "UpdateCogLayersToSourceFormat: Failed to extract COG URL from #{tile_url}: #{e.message}"
    nil
  end
end
