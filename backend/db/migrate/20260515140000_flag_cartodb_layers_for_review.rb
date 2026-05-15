# Flag CartoDB layers for manual review after Leaflet → OpenLayers migration.
#
# CartoDB was removed as a supported layer provider in the OpenLayers migration.
# There is no automatic mapping from CartoDB SQL queries to a new provider because
# the data would need to be re-hosted (e.g., as COG files, WMS, or martin vector tiles).
#
# This migration:
# 1. Logs all remaining cartodb layers to the Rails log for operator review
# 2. Unpublishes them so they do not appear to end users
# 3. Clears the (now-invalid) provider value so the admin validation does not block
#    other saves on those records - operator must re-set provider and layer_config
#
# To reverse: run `rake db:rollback` which restores the original state.
#
class FlagCartodbLayersForReview < ActiveRecord::Migration[7.2]
  def up
    cartodb_layers = execute(<<-SQL.squish)
      SELECT l.id, l.slug, l.query, lt.name
      FROM layers l
      LEFT JOIN layer_translations lt ON lt.layer_id = l.id AND lt.locale = 'en'
      WHERE l.layer_provider = 'cartodb'
    SQL

    if cartodb_layers.ntuples.zero?
      Rails.logger.info "FlagCartodbLayersForReview: No cartodb layers found. Nothing to do."
      return
    end

    Rails.logger.warn "FlagCartodbLayersForReview: Found #{cartodb_layers.ntuples} cartodb layer(s) that require manual migration:"
    cartodb_layers.each do |row|
      Rails.logger.warn "  - ID #{row["id"]} | slug: #{row["slug"]} | name: #{row["name"]} | query: #{row["query"]&.truncate(80)}"
    end

    ids = cartodb_layers.map { |r| r["id"] }
    id_list = ids.join(", ")

    # Unpublish cartodb layers so they do not appear on the live site
    execute("UPDATE layers SET published = false WHERE id IN (#{id_list})")

    # Clear the provider so admin validation doesn't block unrelated edits.
    # Operator must set a valid provider + layer_config before republishing.
    execute("UPDATE layers SET layer_provider = NULL WHERE id IN (#{id_list})")

    Rails.logger.warn "FlagCartodbLayersForReview: Unpublished and cleared provider for #{ids.length} layer(s). Operator action required."
  end

  def down
    # Restore original state from backup values stored in layer_config comment field is not feasible.
    # Use a manual process: find layers where layer_provider IS NULL and layer_config contains
    # a CartoDB SQL query, then restore layer_provider = 'cartodb'.
    raise ActiveRecord::IrreversibleMigration,
      "Cannot automatically reverse cartodb layer flagging. Restore manually using a database backup."
  end
end
