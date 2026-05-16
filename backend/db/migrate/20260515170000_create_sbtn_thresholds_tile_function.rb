# Creates the persistent sbtn_thresholds data table and the Martin function
# source that serves SBTN Thresholds ecoregion data as MVT vector tiles.
#
# The sbtn_thresholds table is populated by db/data/thresholds/seed.rb.
# The function joins that table with ecoregion geometries from
# ldn_dissolved_geometries, which is populated by `rake ldn:build_dimensions`.
#
# Martin auto-discovers sbtn_thresholds_tiles as a function source and serves
# it at /sbtn_thresholds_tiles/{z}/{x}/{y}.
#
# If ldn_dissolved_geometries does not yet exist (e.g. on a fresh deploy),
# Martin logs a warning (on_invalid: warn) and the function is not registered
# — tiles return 404 until `rake ldn:build_dimensions` and the thresholds seed
# have both been run.
class CreateSbtnThresholdsTileFunction < ActiveRecord::Migration[7.2]
  def up
    # Persistent data table — populated by db/data/thresholds/seed.rb.
    execute <<~SQL
      CREATE TABLE IF NOT EXISTS sbtn_thresholds (
        eco_id                  integer PRIMARY KEY,
        ecoregion               text,
        natural_land_baseline   double precision,
        natural_land_threshold  double precision,
        natural_land_exceedance double precision,
        nitrogen_dep_baseline   double precision,
        nitrogen_dep_threshold  double precision,
        nitrogen_dep_exceedance double precision,
        soil_erosion_baseline   double precision,
        soil_erosion_threshold  double precision,
        soil_erosion_exceedance double precision,
        soc_baseline            double precision,
        soc_threshold           double precision,
        soc_exceedance          double precision
      );
    SQL

    # Martin function source.
    execute <<~SQL
      CREATE OR REPLACE FUNCTION sbtn_thresholds_tiles(
        z integer, x integer, y integer, query_params json DEFAULT '{}'
      )
      RETURNS bytea
      LANGUAGE plpgsql
      STABLE
      PARALLEL SAFE
      AS $$
      DECLARE
        mvt    bytea;
        bounds geometry;
      BEGIN
        bounds := ST_TileEnvelope(z, x, y);

        SELECT ST_AsMVT(tile, 'sbtn_thresholds', 4096, 'mvt_geom')
        INTO mvt
        FROM (
          SELECT
            t.eco_id,
            t.ecoregion,
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
            ST_AsMVTGeom(
              ST_Transform(g.geom, 3857),
              bounds,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM ldn_dissolved_geometries g
          JOIN sbtn_thresholds t
            ON (g.properties ->> 'eco_id')::integer = t.eco_id
          WHERE g.dimension = 'ecoregion'
            AND g.geom && ST_Transform(bounds, 4326)
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION sbtn_thresholds_tiles IS
        'Martin function source: SBTN Thresholds ecoregion vector tiles. '
        'All indicator columns (baseline/threshold/exceedance) are exposed as '
        'MVT properties for client-side colorRamp styling. '
        'Populated by db/data/thresholds/seed.rb.';
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS sbtn_thresholds_tiles(integer, integer, integer, json);"
    execute "DROP TABLE IF EXISTS sbtn_thresholds;"
  end
end
