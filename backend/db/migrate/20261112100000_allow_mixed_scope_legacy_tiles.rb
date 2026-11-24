class AllowMixedScopeLegacyTiles < ActiveRecord::Migration[8.1]
  def up
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
              OR (EXISTS (SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id = a.layer_group_id
                    JOIN site_scopes s ON s.id = g.site_scope_id WHERE a.layer_id = l.id AND s.password_protected)
                AND NOT (l.security_provenance = 'legacy_public' AND EXISTS (
                  SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id = a.layer_group_id
                  JOIN site_scopes s ON s.id = g.site_scope_id WHERE a.layer_id = l.id AND NOT s.password_protected))))
        ) THEN
          RAISE EXCEPTION 'Source is not approved for public access' USING ERRCODE = '42501';
        END IF;
        RETURN ra_app.private_ra_vector_tile(z, x, y, query_params);
      END;
      $$;
    SQL

    legacy_mixed = Layer.where(security_provenance: "legacy_public", data_policy: "public")
      .joins(layer_groups: :site_scope).where(site_scopes: {password_protected: false}).distinct
      .where(id: Layer.joins(layer_groups: :site_scope).where(site_scopes: {password_protected: true}).select(:id))
    legacy_mixed.in_batches(of: 100) do |batch|
      TilePolicyLifecycle.refresh!(batch.to_a, reason: "legacy_mixed_scope_policy_changed")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Public tile policy changes require explicit review"
  end
end
