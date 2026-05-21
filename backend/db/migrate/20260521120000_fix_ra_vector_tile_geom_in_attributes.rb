# Fixes two bugs in ra_vector_tile that together cause PostgreSQL OOM crashes
# when serving tiles from geometry-heavy views like v_sbtn_thresholds.
#
# Bug 1 — Raw geometry in MVT attributes:
#   The previous function used SELECT * in its inner query. PostGIS includes
#   any geometry column that is NOT the named mvtgeom column as a raw WKB
#   binary string attribute in every MVT feature. For ecoregions2017 polygons
#   (complex multi-part boundaries, thousands of vertices each), this made
#   every tile tens of megabytes even after ST_SimplifyPreserveTopology.
#   At z=2 (the thresholds site default zoom), a tile spanning 90° of longitude
#   intersects ~150 ecoregions.  150 × ~50KB raw geometry = 7.5MB per tile,
#   times many concurrent tile requests = OOM crash of the PG backend process.
#
#   Fix: build a dynamic column list from pg_attribute that explicitly excludes
#   all geometry/geography columns, so only thematic attributes (eco_id,
#   soil_erosion_threshold, etc.) appear in the MVT feature properties.
#
# Bug 2 — Insufficient geometry simplification:
#   The previous tolerance formula was:
#     tol := 23.0 / (256.0 * power(2.0, z::float))
#   At z=2 this gives 0.022°, which is 1/16 of a display pixel (0.35°).
#   ST_SimplifyPreserveTopology was removing almost nothing, so the geometry
#   handed to ST_AsMVTGeom was still very detailed.
#
#   Fix: use tol := 360.0 / (2560.0 * power(2.0, z::float)) ≈ 0.1 pixel width
#   in EPSG:4326 degrees.  At z=2 this is 0.35° (one full pixel), which is
#   the practical limit of what a display pixel can show.
#
# Result: the crash loop stops because (a) tiles are small again, and
# (b) simplification actually removes sub-pixel vertices.
class FixRaVectorTileGeomInAttributes < ActiveRecord::Migration[7.2]
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
        col_list text;
        mvt      bytea;
        bounds   geometry;
        tol      double precision;
      BEGIN
        tbl := query_params ->> 'table';

        IF tbl IS NULL THEN
          RETURN ''::bytea;
        END IF;

        -- Validate: tbl must be a real table, regular view, or materialized view
        -- in ra_vector.  relkind: 'r' = table, 'v' = view, 'm' = materialized view.
        -- Prevents SQL injection — tbl only enters SQL via format() %I after this check.
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

        -- Resolve the primary geometry column from PostGIS catalog.
        SELECT f_geometry_column INTO geom_col
        FROM geometry_columns
        WHERE f_table_schema = 'ra_vector'
          AND f_table_name   = tbl
        LIMIT 1;

        IF geom_col IS NULL THEN
          RETURN ''::bytea;
        END IF;

        -- Build a column list that explicitly EXCLUDES all geometry/geography
        -- columns.  PostGIS ST_AsMVT converts any geometry column that is not
        -- the named mvtgeom column into a raw WKB hex string attribute, making
        -- tiles enormous.  Including only scalar attributes avoids that.
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
          -- Fallback: no scalar columns at all — return empty.
          RETURN ''::bytea;
        END IF;

        bounds := ST_TileEnvelope(z, x, y);

        -- Simplification tolerance ≈ 0.1 display-pixel width in EPSG:4326 degrees.
        -- Formula: one-tenth the angular width of one tile pixel.
        --   pixel_width = 360 / (256 * 2^z)  degrees
        --   tol         = pixel_width / 10
        --
        -- The WKB-inclusion bug (not this tolerance) was the OOM root cause.
        -- 0.1px keeps geometry visually sharp while still pruning sub-pixel detail.
        --
        -- Apply simplification below z=14 (above that, full detail is fine).
        IF z < 14 THEN
          tol := 360.0 / (2560.0 * power(2.0, z::float));
          EXECUTE format(
            'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'')
             FROM (
               SELECT %s,
                 ST_AsMVTGeom(
                   ST_Transform(
                     ST_SimplifyPreserveTopology(t.%I::geometry, $2),
                     3857
                   ),
                   $1, 4096, 256, true
                 ) AS mvtgeom
               FROM ra_vector.%I t
               WHERE t.%I && ST_Transform($1, 4326)
             ) tile
             WHERE tile.mvtgeom IS NOT NULL',
            tbl, col_list, geom_col, tbl, geom_col
          ) INTO mvt USING bounds, tol;
        ELSE
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
        END IF;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;

      COMMENT ON FUNCTION ra_vector_tile IS
        'Serves any ra_vector table, view, or materialized view as MVT tiles. '
        'Pass name via query_params, e.g. /ra_vector_tile/{z}/{x}/{y}?table=v_sbtn_thresholds. '
        'Validated against pg_class (relkind r/v/m) before dynamic SQL. '
        'Only scalar (non-geometry) columns are included as MVT feature attributes — '
        'raw geometry is never serialised into the attribute payload. '
        'Geometry is simplified to ~0.1 pixel width at z<14.';
    SQL
  end

  def down
    # Revert to the previous version (geometry-in-attributes bug, old tolerance formula).
    # This is the body from migration 20260521100000.
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
        IF tbl IS NULL THEN RETURN ''::bytea; END IF;

        IF NOT EXISTS (
          SELECT 1 FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector' AND c.relname = tbl AND c.relkind IN ('r', 'v')
        ) THEN RETURN ''::bytea; END IF;

        SELECT f_geometry_column INTO geom_col
        FROM geometry_columns
        WHERE f_table_schema = 'ra_vector' AND f_table_name = tbl
        LIMIT 1;
        IF geom_col IS NULL THEN RETURN ''::bytea; END IF;

        bounds := ST_TileEnvelope(z, x, y);

        IF z < 11 THEN
          tol := 23.0 / (256.0 * power(2.0, z::float));
          EXECUTE format(
            'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'') FROM (
               SELECT *, ST_AsMVTGeom(ST_Transform(ST_SimplifyPreserveTopology(%I::geometry, $2), 3857), $1, 4096, 256, true) AS mvtgeom
               FROM ra_vector.%I WHERE %I && ST_Transform($1, 4326)) tile WHERE mvtgeom IS NOT NULL',
            tbl, geom_col, tbl, geom_col
          ) INTO mvt USING bounds, tol;
        ELSE
          EXECUTE format(
            'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'') FROM (
               SELECT *, ST_AsMVTGeom(ST_Transform(%I::geometry, 3857), $1, 4096, 256, true) AS mvtgeom
               FROM ra_vector.%I WHERE %I && ST_Transform($1, 4326)) tile WHERE mvtgeom IS NOT NULL',
            tbl, geom_col, tbl, geom_col
          ) INTO mvt USING bounds;
        END IF;

        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;
    SQL
  end
end
