# Creates a PostGIS function that Martin auto-discovers as a function source.
# Martin serves it at /boundary_tiles/{z}/{x}/{y} as MVT vector tiles.
#
# All boundary tile rendering happens inside PostGIS via this function.
# Martin handles HTTP serving, caching headers, and connection pooling.
class CreateBoundaryTilesFunction < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION boundary_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}')
      RETURNS bytea AS $$
      DECLARE
        max_level integer;
        tolerance double precision;
        mvt bytea;
        tile_env geometry;
        buffered_env geometry;
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

        -- Simplification tolerance in EPSG:3857 metres.
        -- Earth circumference ~40075017m; at zoom z one tile ~= 40075017 / 2^z.
        -- 4096 MVT extent → 1 texel = tile_width / 4096.
        -- Use ~8 texel tolerance for simplification.
        tolerance := 40075016.68 / (power(2, z) * 512);

        -- Expand the spatial filter by the MVT buffer (256 texels)
        -- so features slightly outside the tile are still included and
        -- their simplified edges blend seamlessly with neighbouring tiles.
        buffered_env := ST_Expand(tile_env, tolerance * 32);

        SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') INTO mvt
        FROM (
          SELECT
            name,
            iso_code,
            admin_level,
            ST_AsMVTGeom(
              ST_SimplifyPreserveTopology(
                ST_MakeValid(ST_Transform(geom, 3857)),
                tolerance
              ),
              tile_env,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM admin_boundaries
          WHERE geom && ST_Transform(buffered_env, 4326)
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
