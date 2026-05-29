# Fixes missing boundaries for countries with complex MultiPolygon geometries.
#
# Issue:
#   ST_Boundary(geom) can return GEOMETRYCOLLECTION or empty results for
#   MultiPolygon geometries, especially countries with islands (Brazil, India).
#   The previous implementation lost these boundaries in the MVT output.
#
# Fix:
#   Use ST_Dump to decompose MultiPolygons into individual polygons, then
#   extract exterior rings as linestrings. This ensures all country boundaries
#   are captured, including islands and exclaves.
#
# Note: We use DISTINCT ON to deduplicate shared boundaries between adjacent
# polygons (e.g., border between two countries).
class FixBoundaryTilesMultipolygonSupport < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ra_app.boundary_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}')
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
              boundary_geom,
              tile_env,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM (
            SELECT DISTINCT ON (name, iso_code, admin_level, boundary_geom)
              ab.name,
              ab.iso_code,
              ab.admin_level,
              -- Extract exterior ring from each polygon part.
              -- For MultiPolygon: ST_Dump splits into individual Polygons,
              -- then ST_ExteriorRing gets the outer boundary as LineString.
              ST_Transform(
                ST_ExteriorRing((ST_Dump(ab.geom)).geom),
                3857
              ) as boundary_geom
            FROM ra_app.admin_boundaries ab
            WHERE ab.geom && ST_Transform(tile_env, 4326)
              AND ab.admin_level <= max_level
          ) AS boundaries
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

      COMMENT ON FUNCTION ra_app.boundary_tiles IS
        'Martin function source: admin boundary vector tiles with zoom-dependent filtering. Uses ST_Dump + ST_ExteriorRing for robust MultiPolygon support.';
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ra_app.boundary_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}')
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
              ST_Boundary(ST_Transform(geom, 3857)),
              tile_env,
              4096,
              256,
              true
            ) AS mvt_geom
          FROM ra_app.admin_boundaries
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
