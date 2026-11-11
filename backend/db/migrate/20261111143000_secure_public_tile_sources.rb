class SecurePublicTileSources < ActiveRecord::Migration[8.1]
  def up
    add_column :layers, :public_data, :boolean, null: false, default: false
    install_tile_functions
  end

  def install_tile_functions
    execute <<~SQL
      CREATE OR REPLACE FUNCTION ra_app.private_ra_vector_tile(z integer, x integer, y integer, query_params json DEFAULT '{}'::json)
      RETURNS bytea LANGUAGE plpgsql STABLE PARALLEL RESTRICTED
      SET search_path = ra_app, ra_vector, public
      SET max_parallel_workers_per_gather = 0 AS $$
      DECLARE
        tbl text := query_params ->> 'table';
        geom_col text;
        col_list text;
        bounds geometry;
        mvt bytea;
      BEGIN
        IF z < 0 OR z > 22 OR x < 0 OR y < 0 OR x >= power(2, z) OR y >= power(2, z) THEN
          RAISE EXCEPTION 'Invalid tile coordinates' USING ERRCODE = '22023';
        END IF;
        IF NOT EXISTS (
          SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'ra_vector' AND c.relname = tbl AND c.relkind IN ('r', 'v', 'm')
        ) THEN
          RAISE EXCEPTION 'Unknown vector source' USING ERRCODE = '22023';
        END IF;
        SELECT f_geometry_column INTO geom_col FROM public.geometry_columns
          WHERE f_table_schema = 'ra_vector' AND f_table_name = tbl LIMIT 1;
        IF geom_col IS NULL THEN
          RAISE EXCEPTION 'Source has no geometry column' USING ERRCODE = '22023';
        END IF;
        SELECT string_agg(format('t.%I', a.attname), ', ' ORDER BY a.attnum) INTO col_list
          FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_type tp ON tp.oid = a.atttypid
          WHERE n.nspname = 'ra_vector' AND c.relname = tbl AND a.attnum > 0
            AND NOT a.attisdropped AND tp.typname NOT IN ('geometry', 'geography');
        bounds := ST_TileEnvelope(z, x, y);
        EXECUTE format(
          'SELECT ST_AsMVT(tile, %L, 4096, ''mvtgeom'') FROM (
            SELECT %s ST_AsMVTGeom(ST_Transform(t.%I::geometry, 3857), $1, 4096, 256, true) AS mvtgeom
            FROM ra_vector.%I t WHERE t.%I && ST_Transform($1, 4326)
          ) tile WHERE mvtgeom IS NOT NULL',
          tbl, CASE WHEN col_list IS NULL THEN '' ELSE col_list || ', ' END, geom_col, tbl, geom_col
        ) INTO mvt USING bounds;
        RETURN COALESCE(mvt, ''::bytea);
      END;
      $$;
      REVOKE ALL ON FUNCTION ra_app.private_ra_vector_tile(integer, integer, integer, json) FROM PUBLIC;

      CREATE OR REPLACE FUNCTION ra_app.scope_dataset_tiles(z integer, x integer, y integer, query_params json DEFAULT '{}'::json)
      RETURNS bytea LANGUAGE plpgsql STABLE PARALLEL SAFE SET search_path = ra_app, ra_vector, public AS $$
      DECLARE result bytea;
      BEGIN
        SELECT ST_AsMVT(tile, 'scope_dataset_geometries', 4096, 'mvtgeom') INTO result
        FROM (
          SELECT g.unit_id, g.properties,
                 ST_AsMVTGeom(ST_Transform(g.geom, 3857), ST_TileEnvelope(z, x, y), 4096, 256, true) AS mvtgeom
          FROM scope_dataset_geometries g
          WHERE g.scope_dataset_id = (query_params ->> 'scope_dataset_id')::integer
            AND g.geom && ST_Transform(ST_TileEnvelope(z, x, y), 4326)
        ) tile WHERE mvtgeom IS NOT NULL;
        RETURN COALESCE(result, ''::bytea);
      END;
      $$;
      REVOKE ALL ON FUNCTION ra_app.scope_dataset_tiles(integer, integer, integer, json) FROM PUBLIC;

      CREATE OR REPLACE FUNCTION public.ra_vector_tile(z integer, x integer, y integer, query_params json DEFAULT '{}'::json)
      RETURNS bytea LANGUAGE plpgsql STABLE PARALLEL RESTRICTED
      SET search_path = ra_app, public AS $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM layers l
          WHERE l.published AND l.public_data AND l.layer_provider = 'martin'
            AND COALESCE(l.layer_config::jsonb #>> '{body,params,table}',
                         l.layer_config::jsonb #>> '{body,source}',
                         l.layer_config::jsonb ->> 'source') = query_params ->> 'table'
            AND EXISTS (SELECT 1 FROM agrupations a WHERE a.layer_id = l.id)
            AND NOT EXISTS (
              SELECT 1 FROM agrupations a
              JOIN layer_groups lg ON lg.id = a.layer_group_id
              JOIN site_scopes s ON s.id = lg.site_scope_id
              WHERE a.layer_id = l.id AND s.password_protected
            )
        ) THEN
          RAISE EXCEPTION 'Source is not approved for public access' USING ERRCODE = '42501';
        END IF;
        RETURN ra_app.private_ra_vector_tile(z, x, y, query_params);
      END;
      $$;

      CREATE OR REPLACE FUNCTION ra_app.ra_vector_tile(z integer, x integer, y integer, query_params json DEFAULT '{}'::json)
      RETURNS bytea LANGUAGE sql STABLE PARALLEL RESTRICTED AS $$
        SELECT public.ra_vector_tile(z, x, y, query_params);
      $$;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Do not restore unrestricted public tile serving"
  end
end
