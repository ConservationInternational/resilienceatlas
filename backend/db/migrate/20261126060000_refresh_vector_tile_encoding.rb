class RefreshVectorTileEncoding < ActiveRecord::Migration[8.1]
  def up
    # Encoding changes invalidate bytes without changing source access policy.
    execute <<~SQL
      WITH changed AS (
        UPDATE layers SET tile_cache_version = md5(random()::text || clock_timestamp()::text || id::text)
        WHERE layer_provider = 'martin'
        RETURNING id, tile_cache_version
      ), invalidations AS (
        INSERT INTO tile_cache_invalidations (layer_id, paths, status, created_at, updated_at)
        SELECT id, jsonb_build_array('/api/public-tiles/' || id || '/*',
          '/ra_vector_tile/*', '/ra_app.ra_vector_tile/*', '/api/layers*', '/api/layer_groups*'),
          'pending', now(), now() FROM changed
        RETURNING id
      )
      INSERT INTO tile_security_events (layer_id, action, reason, details, created_at, updated_at)
      SELECT id, 'tile_policy_changed', 'vector_tile_binary_encoding_changed',
        jsonb_build_object('version', tile_cache_version), now(), now() FROM changed
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Do not restore cached text-encoded vector tiles"
  end
end
