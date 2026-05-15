# Fixes tile-edge grid artifacts by converting polygons to linestrings
# before MVT encoding.
#
# Root cause: Leaflet's Canvas renderer clips POLYGONS using the
# Sutherland-Hodgman algorithm, which creates artificial straight edges
# along tile boundaries.  Those edges are rendered as strokes (even with
# fill:false), producing a visible grid.
#
# Fix: ST_Boundary() converts each polygon to its outline linestring
# BEFORE ST_AsMVTGeom.  Leaflet clips LINESTRINGS using Cohen-Sutherland,
# which merely truncates — no artificial edges are created.
class FixBoundaryTilesUseLinestrings < ActiveRecord::Migration[7.2]
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

        SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') INTO mvt
        FROM (
          SELECT
            name,
            iso_code,
            admin_level,
            ST_AsMVTGeom(
              ST_Boundary(ST_Transform(geom, 3857)),
              tile_env,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM admin_boundaries
          WHERE geom && ST_Transform(tile_env, 4326)
            AND admin_level <= max_level
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

      COMMENT ON FUNCTION boundary_tiles IS
        'Martin function source: admin boundary vector tiles with zoom-dependent level filtering (linestring output)';
    SQL
  end

  def down
    # Revert to polygon-based output (has tile-edge artifacts)
    execute <<~SQL
      CREATE OR REPLACE FUNCTION boundary_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}')
      RETURNS bytea AS $$
      DECLARE
        max_level integer;
        mvt bytea;
        tile_env geometry;
      BEGIN
        IF z <= 4 THEN
          max_level := 0;
        ELSIF z <= 7 THEN
          max_level := 1;
        ELSE
          max_level := 2;
        END IF;

        tile_env := ST_TileEnvelope(z, x, y);

        SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') INTO mvt
        FROM (
          SELECT
            name,
            iso_code,
            admin_level,
            ST_AsMVTGeom(
              ST_Transform(geom, 3857),
              tile_env,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM admin_boundaries
          WHERE geom && ST_Transform(tile_env, 4326)
            AND admin_level <= max_level
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;
    SQL
  end
end
