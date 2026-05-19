# Fixes sbtn_thresholds_tiles — two bugs introduced in migration 20260519100000:
#
# 1. Schema resolution failure at tile-request time.
#    When Rails runs a migration the connection has schema_search_path =
#    ra_app,ra_vector,ra_raster,public (database.yml), so the function body
#    compiled successfully.  But Martin uses its own DB connection whose
#    search_path only covers ra_app — so unqualified `ecoregions2017` triggers
#    "relation does not exist" every time a tile is requested.
#
#    Generalized fix: add `SET search_path = ra_app, ra_vector, ra_raster, public`
#    to the function definition.  PostgreSQL applies this search path for the
#    entire duration of every call, regardless of the caller's session path.
#    This is the standard PostgreSQL idiom for cross-schema functions and means
#    the function will resolve tables correctly no matter which connection
#    (Rails, Martin, psql, etc.) invokes it.
#
# 2. Wrong geometry column name.
#    ecoregions2017 was imported via GPKG; the geometry column is `geom`, not
#    `the_geom` (the CartoDB convention).  Two references to `e.the_geom` in
#    the previous migration caused a "column does not exist" error that would
#    have surfaced once the search-path problem was resolved.
class FixSbtnThresholdsGeomColumn < ActiveRecord::Migration[7.2]
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
    # Revert to the state left by 20260519100000 (wrong column, no SET search_path).
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
              ST_Transform(e.the_geom, 3857),
              bounds,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM ecoregions2017 e
          JOIN sbtn_thresholds t
            ON e.eco_id::integer = t.eco_id
          WHERE e.the_geom && ST_Transform(bounds, 4326)
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;
    SQL
  end
end
