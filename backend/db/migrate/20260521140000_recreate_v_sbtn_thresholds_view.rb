# The view ra_vector.v_sbtn_thresholds was dropped on staging by a previous
# version of seed.rb that attempted to convert it to a materialized view.
# The CREATE MATERIALIZED VIEW crashed the DB (same glibc/GEOS issue), leaving
# the view absent.  This migration recreates it as a plain SQL view.
class RecreateVSbtnThresholdsView < ActiveRecord::Migration[7.2]
  def up
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
    SQL
  end

  def down
    execute "DROP VIEW IF EXISTS ra_vector.v_sbtn_thresholds;"
  end
end
