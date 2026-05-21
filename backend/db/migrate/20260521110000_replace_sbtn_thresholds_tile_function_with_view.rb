# Replaces the sbtn_thresholds_tiles custom Martin function with a PostgreSQL
# view in ra_vector, served via the generic ra_vector_tile function.
#
# Why:
#   Every new dataset that joins a non-spatial table with ecoregion geometry
#   previously required a bespoke migration to create a dedicated tile function.
#   The extended ra_vector_tile (migration 20260521100000) now supports views,
#   so the pattern is: create a view in ra_vector that does the join → point
#   the layer at ra_vector_tile with params.table = "v_<name>".
#
# What this migration does:
#   1. Creates ra_vector.v_sbtn_thresholds — a view joining ra_nonspatial.sbtn_thresholds
#      with ra_vector.ecoregions2017 on eco_id.
#   2. Updates all sbtn-* martin layer records to use:
#        layer_config.body.source  = "ra_vector_tile"
#        layer_config.body.params  = {"table": "v_sbtn_thresholds"}
#   3. Drops the sbtn_thresholds_tiles function (no longer needed).
class ReplaceSbtnThresholdsTileFunctionWithView < ActiveRecord::Migration[7.2]
  def up
    # 1. Create the view
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
        'geometry. Served as MVT tiles via ra_vector_tile?table=v_sbtn_thresholds. '
        'Populated by db/data/thresholds/seed.rb (requires sbtn_thresholds.csv to be loaded).';
    SQL

    # 2. Repoint all sbtn-* martin layers from sbtn_thresholds_tiles → ra_vector_tile
    execute <<~SQL
      UPDATE layers
      SET layer_config = jsonb_set(
            jsonb_set(
              layer_config::jsonb,
              '{body,source}',
              '"ra_vector_tile"'
            ),
            '{body,params}',
            '{"table": "v_sbtn_thresholds"}'
          )::text
      WHERE layer_provider = 'martin'
        AND layer_config::jsonb #>> '{body,source}' = 'sbtn_thresholds_tiles';
    SQL

    # 3. Drop the now-redundant custom function
    execute "DROP FUNCTION IF EXISTS sbtn_thresholds_tiles(integer, integer, integer, json);"
  end

  def down
    # Restore sbtn_thresholds_tiles function (exact body from 20260519200000)
    execute <<~SQL
      CREATE OR REPLACE FUNCTION sbtn_thresholds_tiles(
        z integer, x integer, y integer, query_params json DEFAULT '{}'
      )
      RETURNS bytea
      LANGUAGE plpgsql
      STABLE
      PARALLEL SAFE
      SET search_path = ra_app, ra_vector, ra_raster, public
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
            ST_AsMVTGeom(
              ST_Transform(e.geom, 3857),
              bounds,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM ecoregions2017 e
          JOIN sbtn_thresholds t
            ON e.eco_id::integer = t.eco_id
          WHERE e.geom && ST_Transform(bounds, 4326)
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;
    SQL

    # Revert layer records back to sbtn_thresholds_tiles
    execute <<~SQL
      UPDATE layers
      SET layer_config = jsonb_set(
            (layer_config::jsonb - 'params'),
            '{body,source}',
            '"sbtn_thresholds_tiles"'
          )::text
      WHERE layer_provider = 'martin'
        AND layer_config::jsonb #>> '{body,source}' = 'ra_vector_tile'
        AND layer_config::jsonb #>> '{body,params,table}' = 'v_sbtn_thresholds';
    SQL

    execute "DROP VIEW IF EXISTS ra_vector.v_sbtn_thresholds;"
  end
end
