class CreateScopeDatasetGeometriesTilesFunction < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION scope_dataset_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}'::json)
      RETURNS bytea
      LANGUAGE plpgsql
      STABLE
      PARALLEL SAFE
      AS $$
      DECLARE
        mvt bytea;
        bounds geometry;
        ds_id integer;
      BEGIN
        -- Extract optional scope_dataset_id from query params
        ds_id := (query_params ->> 'scope_dataset_id')::integer;

        -- Calculate tile bounds (Web Mercator)
        bounds := ST_TileEnvelope(z, x, y);

        SELECT ST_AsMVT(tile, 'scope_dataset_geometries', 4096, 'mvtgeom')
        INTO mvt
        FROM (
          SELECT
            g.unit_id,
            g.properties,
            ST_AsMVTGeom(
              ST_Transform(g.geom, 3857),
              bounds,
              4096,
              256,
              true
            ) AS mvtgeom
          FROM scope_dataset_geometries g
          WHERE (ds_id IS NULL OR g.scope_dataset_id = ds_id)
            AND g.geom && ST_Transform(bounds, 4326)
        ) AS tile
        WHERE mvtgeom IS NOT NULL;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION scope_dataset_tiles IS 'Serves scope dataset geometries as MVT tiles, optionally filtered by scope_dataset_id';
    SQL
  end

  def down
    execute <<~SQL
      DROP FUNCTION IF EXISTS scope_dataset_tiles(integer, integer, integer, json);
    SQL
  end
end
