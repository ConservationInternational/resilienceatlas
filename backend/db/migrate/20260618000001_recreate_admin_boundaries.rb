# frozen_string_literal: true

# Recreate the admin_boundaries table that was prematurely dropped by
# DropAdminBoundaries (20260529120000). That migration removed the table
# to stop serving it via Martin vector tiles, but the table is still needed
# by the API (AdminBoundariesController) and the spatial analysis feature
# (ScopeDatasetsController#intersecting_units).
#
# Boundary display on the map is still handled by Mapbox Streets client-side;
# this table is used exclusively for:
#   - GET /api/admin-boundaries       (country selector in the Analysis Panel)
#   - GET /api/admin-boundaries/:iso  (country geometry for the analysis overlay)
#   - spatial intersection queries in ScopeDatasetsController
#
# After running this migration, re-import boundary data with:
#   backend/scripts/import_geoboundaries.sh
class RecreateAdminBoundaries < ActiveRecord::Migration[7.2]
  def up
    create_table :admin_boundaries do |t|
      t.string :name
      t.string :iso_code
      t.integer :admin_level, default: 0, null: false
      t.string :parent_iso_code
      t.timestamps null: false
      t.column :geom, :geometry, limit: {srid: 4326, type: "multi_polygon"}, null: false
    end

    add_index :admin_boundaries, :admin_level
    add_index :admin_boundaries, :iso_code
    add_index :admin_boundaries, :geom, using: :gist
  end

  def down
    drop_table :admin_boundaries
  end
end
