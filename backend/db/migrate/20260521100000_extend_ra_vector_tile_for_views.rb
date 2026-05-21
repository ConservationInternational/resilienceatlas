# Extends ra_vector_tile to also serve PostgreSQL views in the ra_vector schema.
#
# Previously the table-name guard only accepted base tables (relkind = 'r').
# This excluded views, which prevented the ra_vector_tile function from serving
# data created via CREATE VIEW — e.g. a view that joins a non-spatial table from
# ra_nonspatial with an ecoregion geometry table in ra_vector.
#
# Security model is unchanged:
#   - The caller-supplied name is validated against pg_class (ra_vector schema)
#     before any dynamic SQL is built.  Only 'r' (table) and 'v' (view) are
#     accepted; materialized views, foreign tables, sequences, etc. are rejected.
#   - The name is never interpolated as a string literal — it goes through
#     format() as a %I identifier after the pg_class guard.
#   - All other OOM/parallel-worker protections from the previous migration are
#     preserved unchanged.
class ExtendRaVectorTileForViews < ActiveRecord::Migration[7.2]
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
      PARALLEL RESTRICTED
      SET search_path = ra_app, ra_vector, ra_raster, public
      SET max_parallel_workers_per_gather = 0
      AS $$
      DECLARE
        tbl      text;
        geom_col text;
        mvt      bytea;
        bounds   geometry;
        tol      double precision;
      BEGIN
        tbl := query_params ->> 'table';

        IF tbl IS NULL THEN
          RETURN ''::bytea;
        END IF;

        -- Validate: tbl must be a real base table OR a view in ra_vector.
        -- relkind: 'r' = ordinary table, 'v' = view.
        -- This prevents SQL injection — tbl is only used in format() as a %I
        -- identifier after this guard.
        IF NOT EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector'
            AND c.relname = tbl
            AND c.relkind IN ('r', 'v')
        ) THEN
          RETURN ''::bytea;
        END IF;

        -- Resolve geometry column from PostGIS catalog.
        -- Works for both tables and views (PostGIS geometry_columns covers both).
        SELECT f_geometry_column INTO geom_col
        FROM geometry_columns
        WHERE f_table_schema = 'ra_vector'
          AND f_table_name   = tbl
        LIMIT 1;

        IF geom_col IS NULL THEN
          RETURN ''::bytea;
        END IF;

        bounds := ST_TileEnvelope(z, x, y);

        -- At z < 11, simplify geometry to ~half a pixel width in EPSG:4326 degrees.
        IF z < 11 THEN
          tol := 23.0 / (256.0 * power(2.0, z::float));
          EXECUTE format(
            'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'')
             FROM (
               SELECT *,
                 ST_AsMVTGeom(
                   ST_Transform(ST_SimplifyPreserveTopology(%I::geometry, $2), 3857),
                   $1, 4096, 256, true
                 ) AS mvtgeom
               FROM ra_vector.%I
               WHERE %I && ST_Transform($1, 4326)
             ) tile
             WHERE mvtgeom IS NOT NULL',
            tbl, geom_col, tbl, geom_col
          ) INTO mvt USING bounds, tol;
        ELSE
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
        END IF;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION ra_vector_tile IS
        'Serves any ra_vector table or view as MVT tiles without requiring a Martin restart. '
        'Pass the table/view name via query_params, e.g. /ra_vector_tile/{z}/{x}/{y}?table=v_sbtn_thresholds. '
        'The name is validated against pg_class (ra_vector schema, relkind r or v) before use, '
        'preventing SQL injection. Geometry is simplified at z<11 to prevent OOM on complex datasets. '
        'Views that join ra_nonspatial data with ra_vector geometry are fully supported.';
    SQL
  end

  def down
    # Revert to tables-only validation (relkind = 'r')
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
      PARALLEL RESTRICTED
      SET search_path = ra_app, ra_vector, ra_raster, public
      SET max_parallel_workers_per_gather = 0
      AS $$
      DECLARE
        tbl      text;
        geom_col text;
        mvt      bytea;
        bounds   geometry;
        tol      double precision;
      BEGIN
        tbl := query_params ->> 'table';

        IF tbl IS NULL THEN
          RETURN ''::bytea;
        END IF;

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

        SELECT f_geometry_column INTO geom_col
        FROM geometry_columns
        WHERE f_table_schema = 'ra_vector'
          AND f_table_name   = tbl
        LIMIT 1;

        IF geom_col IS NULL THEN
          RETURN ''::bytea;
        END IF;

        bounds := ST_TileEnvelope(z, x, y);

        IF z < 11 THEN
          tol := 23.0 / (256.0 * power(2.0, z::float));
          EXECUTE format(
            'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'')
             FROM (
               SELECT *,
                 ST_AsMVTGeom(
                   ST_Transform(ST_SimplifyPreserveTopology(%I::geometry, $2), 3857),
                   $1, 4096, 256, true
                 ) AS mvtgeom
               FROM ra_vector.%I
               WHERE %I && ST_Transform($1, 4326)
             ) tile
             WHERE mvtgeom IS NOT NULL',
            tbl, geom_col, tbl, geom_col
          ) INTO mvt USING bounds, tol;
        ELSE
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
        END IF;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION ra_vector_tile IS
        'Serves any ra_vector table as MVT tiles without requiring a Martin restart. '
        'Pass the table name via query_params, e.g. /ra_vector_tile/{z}/{x}/{y}?table=imported_slug. '
        'The table name is validated against pg_class (ra_vector schema, base tables only) '
        'to prevent SQL injection. Geometry is simplified at z<11 to prevent OOM on complex datasets.';
    SQL
  end
end
