# frozen_string_literal: true

# Drop admin_boundaries table and related indexes/functions after migration to Mapbox Streets.
#
# The admin_boundaries table was used to serve boundary vector tiles via Martin.
# After migrating to Mapbox Streets V4 API, this table and all related infrastructure
# (boundary_tiles function, import scripts) are no longer needed.
#
# This migration:
# 1. Drops the boundary_tiles function (if exists)
# 2. Drops the admin_boundaries table with all its indexes and constraints
class DropAdminBoundaries < ActiveRecord::Migration[7.2]
  def up
    # Drop the boundary_tiles function used by Martin (if it exists)
    execute <<-SQL
      DROP FUNCTION IF EXISTS ra_app.boundary_tiles(integer, integer, integer, jsonb);
    SQL

    # Drop the admin_boundaries table
    drop_table :admin_boundaries, if_exists: true
  end

  def down
    # Reverting this migration is not supported - use Mapbox Streets instead
    raise ActiveRecord::IrreversibleMigration,
          'Cannot recreate admin_boundaries table - use Mapbox Streets V4 API instead'
  end
end
