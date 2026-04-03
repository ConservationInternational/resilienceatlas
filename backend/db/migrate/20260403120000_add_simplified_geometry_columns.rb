# Adds pre-simplified geometry columns for artifact-free vector tile serving.
#
# Simplifying at import time (rather than per-tile) guarantees that shared
# edges between adjacent polygons are simplified identically, eliminating
# the seam / box artifacts that occur with per-tile simplification.
#
# Columns:
#   geom_z0  – aggressively simplified for zoom 0-4  (~0.1° ≈ 11 km tolerance)
#   geom_z5  – moderately simplified for zoom 5-7    (~0.005° ≈ 500 m tolerance)
#   geom     – original full-resolution for zoom 8+  (unchanged)
#
# After running this migration, re-run `rake boundaries:import` to populate
# the new columns (or `rake boundaries:simplify` to update in-place).
class AddSimplifiedGeometryColumns < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      ALTER TABLE admin_boundaries
        ADD COLUMN geom_z0 geometry(MultiPolygon, 4326),
        ADD COLUMN geom_z5 geometry(MultiPolygon, 4326);

      CREATE INDEX index_admin_boundaries_on_geom_z0
        ON admin_boundaries USING gist (geom_z0);

      CREATE INDEX index_admin_boundaries_on_geom_z5
        ON admin_boundaries USING gist (geom_z5);
    SQL

    # Populate from existing data if any rows exist
    execute <<~SQL
      UPDATE admin_boundaries SET
        geom_z0 = ST_Multi(ST_SimplifyPreserveTopology(geom, 0.1)),
        geom_z5 = ST_Multi(ST_SimplifyPreserveTopology(geom, 0.005));
    SQL
  end

  def down
    execute <<~SQL
      DROP INDEX IF EXISTS index_admin_boundaries_on_geom_z5;
      DROP INDEX IF EXISTS index_admin_boundaries_on_geom_z0;
      ALTER TABLE admin_boundaries
        DROP COLUMN IF EXISTS geom_z5,
        DROP COLUMN IF EXISTS geom_z0;
    SQL
  end
end
