# Root cause of the production crash confirmed from PostgreSQL server logs:
#
#   signal 9: Killed
#   DETAIL: Failed process was running: SELECT "ra_app"."ra_vector_tile"(...)
#   malloc.c:2379: sysmalloc: Assertion ... failed.
#
# ST_SimplifyPreserveTopology calls GEOS topology algorithms that corrupt the
# glibc malloc arena on certain complex MultiPolygon geometries (many ecoregion
# polygons qualify).  The kernel kills the process via abort() → SIGABRT.
#
# Fix: remove ST_SimplifyPreserveTopology entirely.  ST_AsMVTGeom with
# clip_geom=true clips each polygon to the tile extent and quantizes coordinates
# to the MVT 4096-unit grid — sufficient simplification without GEOS.
#
# Also uses the explicit ra_app. schema prefix so the correct function is
# replaced (migration 20260521120000 used an unqualified name which may have
# created public.ra_vector_tile instead of replacing ra_app.ra_vector_tile).
class FixRaVectorTileRemoveSimplifyPreserveTopology < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ra_app.ra_vector_tile(
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
        col_list text;
        mvt      bytea;
        bounds   geometry;
      BEGIN
        tbl := query_params ->> 'table';

        IF tbl IS NULL THEN
          RETURN ''::bytea;
        END IF;

        -- Validate: tbl must be a real table, regular view, or materialized view
        -- in ra_vector.  relkind: 'r' = table, 'v' = view, 'm' = materialized view.
        IF NOT EXISTS (
          SELECT 1
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector'
            AND c.relname = tbl
            AND c.relkind IN ('r', 'v', 'm')
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

        -- Build a scalar-only column list, explicitly excluding geometry/geography
        -- columns.  PostGIS ST_AsMVT encodes any non-named geometry column as a
        -- raw WKB hex string attribute, which makes tiles extremely large.
        SELECT string_agg(format('t.%I', a.attname), ', ' ORDER BY a.attnum)
        INTO col_list
        FROM pg_attribute a
        JOIN pg_class c ON a.attrelid = c.oid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_type tp ON tp.oid = a.atttypid
        WHERE n.nspname = 'ra_vector'
          AND c.relname = tbl
          AND a.attnum > 0
          AND NOT a.attisdropped
          AND tp.typname NOT IN ('geometry', 'geography');

        IF col_list IS NULL THEN
          RETURN ''::bytea;
        END IF;

        bounds := ST_TileEnvelope(z, x, y);

        -- No ST_SimplifyPreserveTopology: that function's GEOS C code corrupts
        -- the malloc heap on certain complex polygons, crashing the PG backend.
        -- ST_AsMVTGeom(clip_geom=>true) clips to the tile extent and quantizes
        -- to the MVT 4096-unit grid — sufficient for all web map zoom levels.
        EXECUTE format(
          'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'')
           FROM (
             SELECT %s,
               ST_AsMVTGeom(
                 ST_Transform(t.%I::geometry, 3857),
                 $1, 4096, 256, true
               ) AS mvtgeom
             FROM ra_vector.%I t
             WHERE t.%I && ST_Transform($1, 4326)
           ) tile
           WHERE tile.mvtgeom IS NOT NULL',
          tbl, col_list, geom_col, tbl, geom_col
        ) INTO mvt USING bounds;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION ra_app.ra_vector_tile IS
        'Serves any ra_vector table, view, or materialized view as MVT tiles. '
        'Pass name via query_params, e.g. /ra_vector_tile/{z}/{x}/{y}?table=v_sbtn_thresholds. '
        'Validated against pg_class (relkind r/v/m). '
        'Only scalar (non-geometry) columns are included as MVT feature attributes — '
        'raw geometry is never serialised into the attribute payload. '
        'No ST_SimplifyPreserveTopology: removed to prevent glibc heap corruption '
        'in the GEOS library on complex polygon datasets. '
        'ST_AsMVTGeom with clip_geom=true handles tile-appropriate precision.';
    SQL
  end

  def down
    # The old function body (with ST_SimplifyPreserveTopology) caused a crash,
    # so there is no safe rollback target.  Leave the function in place.
  end
end
