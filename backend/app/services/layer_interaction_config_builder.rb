# Builds the interaction_config hash for Layer records based on provider type.
# Extracted from CartodbRakeHelpers so it can be shared between the CartoDB
# migration rake tasks and the admin upload handlers.
#
# Usage:
#   LayerInteractionConfigBuilder.for_cog
#   LayerInteractionConfigBuilder.for_martin("my_table", conn, "ra_vector")
class LayerInteractionConfigBuilder
  # Columns that carry no useful information in a Martin click popup.
  SKIP_COLS = %w[cartodb_id the_geom the_geom_webmercator created_at updated_at ogc_fid].freeze

  # Returns the canonical interaction_config hash for a COG/TiTiler layer.
  # The frontend resolves {{cogUrl}} at click-time from layer_config.body.source.
  def self.for_cog
    {
      "output" => [{"column" => "values.0", "property" => "Value", "type" => "number"}],
      "config" => {"url" => "{{titilerUrl}}/cog/point/{{lng}}/{{lat}}?url={{cogUrl}}"}
    }
  end

  # Builds an interaction_config hash for a Martin vector layer by inspecting
  # the column names of the PostGIS table.
  #
  # @param table_name [String]  Bare table name (no schema prefix)
  # @param conn       [ActiveRecord::ConnectionAdapters::AbstractAdapter]
  # @param schema     [String]  PostgreSQL schema, e.g. "ra_vector"
  # @return [Hash, nil]  interaction_config hash, or nil when no usable columns
  def self.for_martin(table_name, conn, schema = "ra_vector")
    rows = conn.execute(
      "SELECT column_name FROM information_schema.columns " \
      "WHERE table_schema = #{conn.quote(schema)} " \
      "AND table_name = #{conn.quote(table_name)} " \
      "ORDER BY ordinal_position"
    )
    cols = rows.map { |r| r["column_name"] }
      .reject { |c| SKIP_COLS.include?(c) || c.match?(/\A(?:the_)?geom/i) }
    return nil if cols.empty?

    output = cols.map do |c|
      {"column" => c, "property" => c.tr("_", " ").split.map(&:capitalize).join(" ")}
    end
    {"output" => output}
  rescue => e
    Rails.logger.warn "LayerInteractionConfigBuilder.for_martin(#{table_name}): #{e.message}"
    nil
  end
end
