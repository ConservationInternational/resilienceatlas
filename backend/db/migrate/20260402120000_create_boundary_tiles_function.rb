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

        -- Simplification tolerance in EPSG:4326 degrees.
        -- ~8 pixel tolerance: 360 / (2^z * 512)
        tolerance := 360.0 / (power(2, z) * 512);

        SELECT ST_AsMVT(tile, 'boundaries', 4096, 'mvt_geom') INTO mvt
        FROM (
          SELECT
            name,
            iso_code,
            admin_level,
            ST_AsMVTGeom(
              ST_Transform(
                ST_Simplify(geom, tolerance),
                3857
              ),
              ST_TileEnvelope(z, x, y),
              4096,
              64,
              true
            ) AS mvt_geom
          FROM admin_boundaries
          WHERE geom && ST_Transform(ST_TileEnvelope(z, x, y), 4326)
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
