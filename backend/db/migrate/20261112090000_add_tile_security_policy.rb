class AddTileSecurityPolicy < ActiveRecord::Migration[8.1]
  def up
    add_column :layers, :data_policy, :string, null: false, default: "public"
    add_column :layers, :tile_cache_version, :string
    add_column :layers, :security_provenance, :string, null: false, default: "default_public"
    execute "UPDATE layers SET tile_cache_version = md5(random()::text || clock_timestamp()::text || id::text)"
    change_column_null :layers, :tile_cache_version, false
    add_check_constraint :layers, "data_policy IN ('public', 'restricted')", name: "layers_data_policy"
    add_check_constraint :layers, "security_provenance IN ('default_public', 'legacy_public', 'explicit')", name: "layers_security_provenance"
    add_check_constraint :layers, "length(tile_cache_version) > 0", name: "layers_tile_cache_version"

    create_table :tile_source_imports do |t|
      t.string :run_id, null: false
      t.string :identity, null: false
      t.string :operation, null: false
      t.string :fingerprint, null: false
      t.string :status, null: false, default: "staged"
      t.jsonb :source_keys, null: false, default: []
      t.jsonb :layer_ids, null: false, default: []
      t.jsonb :invalidation_ids, null: false, default: []
      t.jsonb :summary, null: false, default: {}
      t.boolean :in_place, null: false, default: true
      t.boolean :global, null: false, default: false
      t.text :error_message
      t.datetime :completed_at
      t.timestamps
    end
    add_index :tile_source_imports, :run_id, unique: true
    add_index :tile_source_imports, [:operation, :fingerprint]
    add_index :tile_source_imports, :status

    create_table :tile_source_generations do |t|
      t.string :source_key, null: false
      t.string :data_version, null: false
      t.string :policy_version, null: false
      t.string :fingerprint
      t.timestamps
    end
    add_index :tile_source_generations, :source_key, unique: true

    restricted_ids = ENV.fetch("TILE_SECURITY_RESTRICTED_LAYER_IDS", "").split(",").reject(&:empty?).map { |id| Integer(id, 10) }
    if restricted_ids.any?
      execute "UPDATE layers SET data_policy = 'restricted', security_provenance = 'explicit', public_data = false WHERE id IN (#{restricted_ids.join(",")})"
    end

    # This cutoff is immutable: later policy revocations are never re-grandfathered.
    # The preceding security migration's false default is not an explicit denial.
    execute <<~SQL
      UPDATE layers l SET security_provenance = 'legacy_public'
      WHERE l.published AND l.data_policy = 'public' AND EXISTS (
        SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id = a.layer_group_id
        JOIN site_scopes s ON s.id = g.site_scope_id
        WHERE a.layer_id = l.id AND NOT s.password_protected
      )
    SQL
    execute <<~SQL
      INSERT INTO tile_source_imports
        (run_id, identity, operation, fingerprint, status, layer_ids, summary, completed_at, created_at, updated_at)
      SELECT 'grandfather-20261112090000', 'migration:20261112090000', 'migration:grandfather', '20261112090000', 'completed',
        COALESCE(jsonb_agg(id), '[]'::jsonb),
        jsonb_build_object('cutoff', '20261112090000', 'published_count', count(*) FILTER (WHERE published),
          'grandfathered_count', count(*) FILTER (WHERE security_provenance = 'legacy_public'),
          'explicit_restriction_count', count(*) FILTER (WHERE data_policy = 'restricted'),
          'evidence', 'local_configuration_only', 'ambiguity', 'Historical false approvals have no recorded revocation provenance; use the restriction manifest for known denials'),
        now(), now(), now()
      FROM layers
    SQL
    execute <<~SQL
      UPDATE layers l SET public_data = true
      WHERE l.security_provenance = 'legacy_public' AND l.layer_provider = 'martin'
        AND NOT EXISTS (
          SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id = a.layer_group_id
          JOIN site_scopes s ON s.id = g.site_scope_id
          WHERE a.layer_id = l.id AND s.password_protected
        )
    SQL
    install_public_guard
  end

  def install_public_guard
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.ra_vector_tile(z integer, x integer, y integer, query_params json DEFAULT '{}'::json)
      RETURNS bytea LANGUAGE plpgsql STABLE PARALLEL RESTRICTED
      SET search_path = ra_app, public AS $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM tile_source_imports i
          WHERE i.status <> 'completed' AND (
            i.global OR EXISTS (
              SELECT 1 FROM layers l WHERE i.layer_ids @> to_jsonb(ARRAY[l.id])
              AND COALESCE(l.layer_config::jsonb #>> '{body,params,table}', l.layer_config::jsonb #>> '{body,source}',
                l.layer_config::jsonb ->> 'source') = query_params ->> 'table'
            )
          )
        ) OR NOT EXISTS (
          SELECT 1 FROM layers l WHERE l.published AND l.public_data AND l.data_policy = 'public'
            AND l.layer_provider = 'martin'
            AND COALESCE(l.layer_config::jsonb #>> '{body,params,table}', l.layer_config::jsonb #>> '{body,source}',
              l.layer_config::jsonb ->> 'source') = query_params ->> 'table'
            AND EXISTS (SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id = a.layer_group_id
              JOIN site_scopes s ON s.id = g.site_scope_id WHERE a.layer_id = l.id AND NOT s.password_protected)
        ) OR EXISTS (
          SELECT 1 FROM layers l WHERE l.layer_provider = 'martin'
            AND COALESCE(l.layer_config::jsonb #>> '{body,params,table}', l.layer_config::jsonb #>> '{body,source}',
              l.layer_config::jsonb ->> 'source') = query_params ->> 'table'
            AND (l.data_policy = 'restricted' OR (l.security_provenance = 'explicit' AND NOT l.public_data)
              OR EXISTS (SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id = a.layer_group_id
                JOIN site_scopes s ON s.id = g.site_scope_id WHERE a.layer_id = l.id AND s.password_protected))
        ) THEN
          RAISE EXCEPTION 'Source is not approved for public access' USING ERRCODE = '42501';
        END IF;
        RETURN ra_app.private_ra_vector_tile(z, x, y, query_params);
      END;
      $$;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Tile policy and durable import history must be retained"
  end
end
