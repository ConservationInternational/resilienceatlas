# Creates a PostGIS function that Martin auto-discovers as a function source.
# Martin serves it at /boundary_tiles/{z}/{x}/{y} as MVT vector tiles.
#
# All boundary tile rendering happens inside PostGIS via this function.
# Martin handles HTTP serving, caching headers, and connection pooling.
#
# Geometry simplification is done at import time (not per-tile) to guarantee
# that shared polygon edges are simplified identically across tiles,
# eliminating seam / box artifacts.  See 20260403120000 migration for the
# pre-simplified columns (geom_z0, geom_z5).
class CreateBoundaryTilesFunction < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION boundary_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}')
      RETURNS bytea AS $$
      DECLARE
        max_level integer;
        mvt bytea;
        tile_env geometry;
      BEGIN
        -- Determine which admin levels to include based on zoom:
        --   zoom 0-4:  ADM0 only (countries)
        --   zoom 5-7:  ADM0 + ADM1 (provinces/states)
        --   zoom 8+:   ADM0 + ADM1 + ADM2 (districts)
        IF z <= 4 THEN
          max_level := 0;
        ELSIF z <= 7 THEN
          max_level := 1;
        ELSE
          max_level := 2;
        END IF;

        -- Tile envelope in Web Mercator (EPSG:3857).
        tile_env := ST_TileEnvelope(z, x, y);

        -- Pick the pre-simplified geometry column based on zoom level:
        --   zoom 0-4:  geom_z0  (~0.1° tolerance, ~11 km)
        --   zoom 5-7:  geom_z5  (~0.005° tolerance, ~500 m)
        --   zoom 8+:   geom     (full resolution)
        --
        -- Simplification was done once at import time on the full unclipped
        -- geometry, so shared edges are identical across all tiles — no
        -- seam artifacts.

        SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') INTO mvt
        FROM (
          SELECT
            name,
            iso_code,
            admin_level,
            ST_AsMVTGeom(
              ST_Transform(
                CASE
                  WHEN z <= 4 THEN COALESCE(geom_z0, geom)
                  WHEN z <= 7 THEN COALESCE(geom_z5, geom)
                  ELSE geom
                END,
                3857
              ),
              tile_env,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM admin_boundaries
          WHERE (
            CASE
              WHEN z <= 4 THEN COALESCE(geom_z0, geom)
              WHEN z <= 7 THEN COALESCE(geom_z5, geom)
              ELSE geom
            END
          ) && ST_Transform(tile_env, 4326)
            AND admin_level <= max_level
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

      COMMENT ON FUNCTION boundary_tiles IS
        'Martin function source: admin boundary vector tiles with zoom-dependent level filtering and pre-simplified geometry';
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS boundary_tiles(integer, integer, integer, json);"
  end
end
