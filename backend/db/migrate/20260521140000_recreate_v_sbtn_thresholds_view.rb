# The view ra_vector.v_sbtn_thresholds was dropped on staging by a previous
# version of seed.rb that attempted to convert it to a materialized view.
# The CREATE MATERIALIZED VIEW crashed the DB (same glibc/GEOS issue), leaving
# the view absent.  This migration recreates it as a plain SQL view.
#
# It also adds a functional index on ecoregions2017(eco_id::integer) so that
# the JOIN condition "e.eco_id::integer = t.eco_id" can use an index scan.
# The CartoDB import creates idx_ecoregions2017_geom (GiST) automatically, so
# only the integer-cast functional index is missing.
class RecreateVSbtnThresholdsView < ActiveRecord::Migration[7.2]
  def up
    return unless source_tables_available?

    execute <<~SQL
      CREATE OR REPLACE VIEW ra_vector.v_sbtn_thresholds AS
      SELECT
        t.eco_id,
        t.ecoregion,
        e.eco_name,
        e.biome_name,
        e.realm,
        t.natural_land_baseline,
        t.natural_land_threshold,
        t.natural_land_exceedance,
        t.nitrogen_dep_baseline,
        t.nitrogen_dep_threshold,
        t.nitrogen_dep_exceedance,
        t.soil_erosion_baseline,
        t.soil_erosion_threshold,
        t.soil_erosion_exceedance,
        t.soc_baseline,
        t.soc_threshold,
        t.soc_exceedance,
        e.geom
      FROM ra_nonspatial.sbtn_thresholds t
      JOIN ra_vector.ecoregions2017 e ON e.eco_id::integer = t.eco_id;

      COMMENT ON VIEW ra_vector.v_sbtn_thresholds IS
        'Joins ra_nonspatial.sbtn_thresholds indicator data with ra_vector.ecoregions2017 '
        'geometry. Served as MVT tiles via ra_vector_tile?table=v_sbtn_thresholds.';

      -- Functional index so the planner can use an index scan for the JOIN
      -- condition "e.eco_id::integer = t.eco_id" rather than casting every row
      -- in a sequential scan.  The cast is necessary because ogr2ogr imports
      -- eco_id as text; the GiST spatial index is created by the CartoDB rake.
      CREATE INDEX IF NOT EXISTS idx_ecoregions2017_eco_id_int
        ON ra_vector.ecoregions2017 ((eco_id::integer));
    SQL
  end

  def down
    execute <<~SQL
      DROP VIEW IF EXISTS ra_vector.v_sbtn_thresholds;
      DROP INDEX IF EXISTS ra_vector.idx_ecoregions2017_eco_id_int;
    SQL
  end

  private

  def source_tables_available?
    select_value("SELECT to_regclass('ra_nonspatial.sbtn_thresholds')").present? &&
      select_value("SELECT to_regclass('ra_vector.ecoregions2017')").present?
  end
end
