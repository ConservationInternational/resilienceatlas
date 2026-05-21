# Fixes two OOM crash causes in ra_vector_tile:
#
# 1. Parallel worker OOM kills.
#    PostgreSQL was spawning parallel workers for the ST_AsMVTGeom query inside
#    EXECUTE.  Each worker allocates its own copy of the geometry data, multiplying
#    peak RAM usage.  The Linux OOM killer then killed the worker (signal 9), which
#    caused PostgreSQL to crash-recover the entire cluster.
#
#    Fix: PARALLEL RESTRICTED prevents the function from being called inside a
#    parallel worker.  SET max_parallel_workers_per_gather=0 prevents the dynamic
#    query inside EXECUTE from spawning its own parallel workers.
#
# 2. No geometry simplification at low zoom levels.
#    Datasets like gmw_2016_v2 (Global Mangrove Watch) contain millions of
#    complex high-resolution polygons.  At z=0-4 a single tile covers a large
#    fraction of the globe, pulling all features at full resolution and requiring
#    gigabytes of RAM just for ST_Transform + ST_AsMVTGeom.
#
#    Fix: apply ST_SimplifyPreserveTopology at z < 11 with a tolerance equal to
#    ~half a pixel width in EPSG:4326 degrees.  Above z=11 the tolerance is
#    sub-pixel so simplification is skipped entirely.
#
#    Tolerance formula: 23.0 / (256 * 2^z)  — ~10 km at z=0, halving each zoom level.
#    10 km ≈ 0.0898° → 0.0898 × 256 ≈ 23.0.
#
#      z=0  → tol ≈ 0.0898° (~10 km at equator)
#      z=4  → tol ≈ 0.00561° (~625 m)
#      z=8  → tol ≈ 0.000351° (~39 m)
#      z=10 → tol ≈ 0.0000877° (~9.8 m)
#      z=11 → no simplification (sub-pixel)
class FixRaVectorTileOom < ActiveRecord::Migration[7.2]
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

        -- At z < 11, simplify geometry to ~half a pixel width in EPSG:4326 degrees.
        -- Formula: 23.0 / (256 * 2^z)  (~10 km at z=0, halving each zoom level)
        -- z=0 → ~0.090° (~10 km); z=4 → ~0.006° (~625 m); z=8 → ~0.00035° (~39 m)
        -- This dramatically reduces vertex count and memory for complex datasets
        -- (e.g. mangrove polygons) at overview zoom levels.
        -- At z >= 11, tolerance would be sub-pixel — skip simplification entirely.
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

  def down
    # Revert to the original version without OOM protections
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
        IF tbl IS NULL THEN RETURN ''::bytea; END IF;
        IF NOT EXISTS (
          SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector' AND c.relname = tbl AND c.relkind = 'r'
        ) THEN RETURN ''::bytea; END IF;
        SELECT f_geometry_column INTO geom_col FROM geometry_columns
        WHERE f_table_schema = 'ra_vector' AND f_table_name = tbl LIMIT 1;
        IF geom_col IS NULL THEN RETURN ''::bytea; END IF;
        bounds := ST_TileEnvelope(z, x, y);
        EXECUTE format(
          'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'')
           FROM (SELECT *, ST_AsMVTGeom(ST_Transform(%I::geometry, 3857), $1, 4096, 256, true) AS mvtgeom
                 FROM ra_vector.%I WHERE %I && ST_Transform($1, 4326)) tile
           WHERE mvtgeom IS NOT NULL',
          tbl, geom_col, tbl, geom_col
        ) INTO mvt USING bounds;
        RETURN COALESCE(mvt, ''::bytea);
      END; $$;
    SQL
  end
end
