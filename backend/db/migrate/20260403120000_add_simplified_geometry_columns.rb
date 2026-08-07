# Previously added geom_z0/geom_z5 pre-simplified columns, but per-polygon
# simplification cannot preserve topology across shared edges between
# adjacent boundaries.  Full-resolution geometry is now used at all zoom
# levels — ST_AsMVTGeom handles clipping and grid quantization.
#
# This migration drops the simplified columns if they exist (idempotent).
class AddSimplifiedGeometryColumns < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:admin_boundaries)

    execute <<~SQL
      DROP INDEX IF EXISTS index_admin_boundaries_on_geom_z5;
      DROP INDEX IF EXISTS index_admin_boundaries_on_geom_z0;
      ALTER TABLE admin_boundaries
        DROP COLUMN IF EXISTS geom_z5,
        DROP COLUMN IF EXISTS geom_z0;
    SQL
  end

  def down
    # No-op: simplified columns are no longer used
  end
end
