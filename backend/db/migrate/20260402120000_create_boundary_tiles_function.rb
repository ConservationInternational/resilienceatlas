# Creates a PostGIS function that Martin auto-discovers as a function source.
# Martin serves it at /boundary_tiles/{z}/{x}/{y} as MVT vector tiles.
#
# All boundary tile rendering happens inside PostGIS via this function.
# Martin handles HTTP serving, caching headers, and connection pooling.
#
# Geometry is converted from polygons to linestrings via ST_Boundary() before
# encoding to MVT.  This is critical: Leaflet's Canvas renderer clips polygons
# using Sutherland-Hodgman (which creates artificial edges at tile boundaries),
# but clips linestrings using Cohen-Sutherland (which just truncates).
# Sending linestrings avoids the grid-line artifacts at tile edges.
#
# No geometry simplification is applied — full-resolution geometry is used
# at all zoom levels.  ST_AsMVTGeom clips to the tile extent and quantizes
# coordinates to the 4096-unit MVT grid, which keeps tiles compact.
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
        'Martin function source: admin boundary vector tiles with zoom-dependent level filtering';
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS boundary_tiles(integer, integer, integer, json);"
  end
end
