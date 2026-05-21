# Creates a Martin function source that serves any table in the ra_vector schema
# as MVT vector tiles without requiring a Martin restart.
#
# Instead of registering each imported table as a direct Martin source (which
# requires restarting Martin to discover the new table), every imported vector
# layer points at this single function source and passes the table name via
# query_params: /ra_vector_tile/{z}/{x}/{y}?table=imported_slug
#
# Security: the table name is validated against pg_class (ra_vector schema only)
# before being interpolated into the dynamic query, preventing SQL injection.
#
# The geometry column is looked up from geometry_columns at call time, so the
# function works regardless of how the column was named during import.
class CreateRaVectorTileFunction < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ra_vector_tile(
        z integer,
        x integer,
        y integer,
        query_params json DEFAULT '{}'::json
      )
      RETURNS bytea
      LANGUAGE plpgsql
      STABLE
      PARALLEL SAFE
      SET search_path = ra_app, ra_vector, ra_raster, public
      AS $$
      DECLARE
        tbl      text;
        geom_col text;
        mvt      bytea;
        bounds   geometry;
      BEGIN
        tbl := query_params ->> 'table';

        -- Null / missing table param → return empty tile
        IF tbl IS NULL THEN
          RETURN ''::bytea;
        END IF;

        -- Validate: tbl must be a real base table in ra_vector.
        -- This check prevents SQL injection — tbl is only used in format()
        -- after passing this guard.
        IF NOT EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector'
            AND c.relname = tbl
            AND c.relkind = 'r'
        ) THEN
          RETURN ''::bytea;
        END IF;

        -- Resolve geometry column from PostGIS catalog
        SELECT f_geometry_column INTO geom_col
        FROM geometry_columns
        WHERE f_table_schema = 'ra_vector'
          AND f_table_name   = tbl
        LIMIT 1;

        IF geom_col IS NULL THEN
          RETURN ''::bytea;
        END IF;

        bounds := ST_TileEnvelope(z, x, y);

        -- Build and execute the MVT query dynamically.
        -- All user-controlled values go through format() identifiers (%I) or
        -- the pg_class guard above — no direct string concatenation.
        EXECUTE format(
          'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'')
           FROM (
             SELECT *,
               ST_AsMVTGeom(
                 ST_Transform(%I::geometry, 3857),
                 $1, 4096, 256, true
               ) AS mvtgeom
             FROM ra_vector.%I
             WHERE %I && ST_Transform($1, 4326)
           ) tile
           WHERE mvtgeom IS NOT NULL',
          tbl, geom_col, tbl, geom_col
        ) INTO mvt USING bounds;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION ra_vector_tile IS
        'Serves any ra_vector table as MVT tiles without requiring a Martin restart. '
        'Pass the table name via query_params, e.g. /ra_vector_tile/{z}/{x}/{y}?table=imported_slug. '
        'The table name is validated against pg_class (ra_vector schema, base tables only) '
        'before use, preventing SQL injection.';
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS ra_vector_tile(integer, integer, integer, json);"
  end
end
