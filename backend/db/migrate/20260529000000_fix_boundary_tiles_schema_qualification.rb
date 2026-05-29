# Fixes "relation admin_boundaries does not exist" when Martin queries the
# boundary_tiles function.
#
# Root cause:
#   Migration 20260515160000_create_ra_schemas moved all Rails-managed tables
#   (including admin_boundaries) from the `public` schema into `ra_app`.
#   The boundary_tiles function was created earlier and references the table by
#   its unqualified name.  Rails finds it because database.yml sets
#   schema_search_path = ra_app,...  Martin's DATABASE_URL connection uses the
#   PostgreSQL default search_path ("$user", public) so `admin_boundaries`
#   resolves to public.admin_boundaries — which no longer exists.
#
# Fix: pin the function's search_path at definition time so it always resolves
# ra_app regardless of the calling session's search_path.
class FixBoundaryTilesSchemaQualification < ActiveRecord::Migration[7.2]
  def up
    # Drop the old function in public schema
    execute "DROP FUNCTION IF EXISTS public.boundary_tiles(integer, integer, integer, json);"
    
    # Create the function in ra_app schema with schema-qualified table reference
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

      COMMENT ON FUNCTION ra_app.boundary_tiles IS
        'Martin function source: admin boundary vector tiles with zoom-dependent level filtering (linestring output)';
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.boundary_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}')
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
          FROM admin_boundaries
          WHERE geom && ST_Transform(tile_env, 4326)
            AND admin_level <= max_level
        ) AS tile
        WHERE mvt_geom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$ LANGUAGE plpgsql STABLE PARALLEL SAFE;

      COMMENT ON FUNCTION public.boundary_tiles IS
        'Martin function source: admin boundary vector tiles with zoom-dependent level filtering (linestring output)';
    SQL
  end
end
