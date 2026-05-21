# Fixes sbtn_thresholds_tiles to use ecoregions2017 for geometry instead
# of ldn_dissolved_geometries, which does not exist on staging.
#
# Root cause: the original migration (20260515170000) referenced
# ldn_dissolved_geometries (an LDN-specific pre-dissolved geometry table
# created by `rake ldn:build_dimensions` in ra_vector schema). That table
# has never been populated on staging, causing Martin to 500 on every tile
# request.
#
# Fix: join directly against ecoregions2017, which is the same table the
# original CartoDB query used.
#
# Schema note: Martin's DB connection does not inherit Rails' schema_search_path
# (ra_app,ra_vector,ra_raster,public from database.yml).  To ensure the
# function resolves unqualified table names correctly regardless of caller,
# we set SET search_path = ra_app, ra_vector, ra_raster, public in the
# function definition itself.  See migration 20260519200000 for the fix
# applied to a staging instance that ran this migration before the search_path
# clause was added.
#
# Also adds eco_name, biome_name, and realm from ecoregions2017 to the
# MVT properties so the interaction popup can display them.
class FixSbtnThresholdsTileFunction < ActiveRecord::Migration[7.2]
  def up
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

      COMMENT ON FUNCTION sbtn_thresholds_tiles IS
        'Martin function source: SBTN Thresholds ecoregion vector tiles. '
        'Joins ecoregions2017 geometry with sbtn_thresholds indicator data. '
        'All indicator columns (baseline/threshold/exceedance) plus '
        'eco_name/biome_name/realm are exposed as MVT properties for '
        'client-side colorRamp styling. Populated by db/data/thresholds/seed.rb.';
    SQL
  end

  def down
    # Restore the original function that depended on ldn_dissolved_geometries.
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
    SQL
  end
end
