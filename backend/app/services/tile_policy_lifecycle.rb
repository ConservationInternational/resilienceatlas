class TilePolicyLifecycle
  POLICY_FIELDS = %w[layer_provider layer_config analysis_body analysis_query interaction_config published data_policy security_provenance public_data].freeze

  def self.invalidation_paths(layer)
    ["/api/public-tiles/#{layer.id}/*", "/ra_vector_tile/*", "/ra_app.ra_vector_tile/*",
      "/api/layers*", "/api/layer_groups*"]
  end

  def self.invalidate!(layer, reason:, previous_version: nil)
    if defined?(TileCacheInvalidation) && TileCacheInvalidation.table_exists?
      TileCacheInvalidation.create!(layer_id: layer.destroyed? ? nil : layer.id, status: "pending",
        paths: invalidation_paths(layer))
    end
    if defined?(TileSecurityEvent) && TileSecurityEvent.table_exists?
      TileSecurityEvent.create!(layer_id: layer.destroyed? ? nil : layer.id, action: "tile_policy_changed", reason: reason,
        details: {"source_key" => TileSecurityPolicy.new(layer).source_key, "previous_version" => previous_version,
                  "version" => layer.tile_cache_version})
    end
  end

  def self.refresh!(layers, reason:, rotate: true, data_changed: false, fingerprint: nil)
    ids = Array(layers).compact.map { |layer| layer.respond_to?(:id) ? layer.id : layer }.uniq
    expanded = Layer.where(id: ids).to_a
    expanded += expanded.flat_map { |layer| TileSecurityPolicy.new(layer).aliases.to_a }
    keys = expanded.filter_map { |layer| TileSecurityPolicy.new(layer).source_key }.uniq
    keys.sort.each do |key|
      generation = TileSourceGeneration.find_or_create_by!(source_key: key) do |entry|
        entry.data_version = SecureRandom.hex(16)
        entry.policy_version = SecureRandom.hex(16)
      end
      generation.with_lock do
        updates = {policy_version: SecureRandom.hex(16)}
        if data_changed
          updates[:data_version] = SecureRandom.hex(16)
          updates[:fingerprint] = fingerprint
        end
        generation.update!(updates) if rotate
      end
    end
    expanded.uniq(&:id).sort_by(&:id).each do |layer|
      layer.with_lock do
        previous = layer.tile_cache_version
        attributes = {}
        attributes[:tile_cache_version] = SecureRandom.hex(16) if rotate
        layer.assign_attributes(attributes)
        # A policy decision, not a second manual approval flag.
        eligible = TileSecurityPolicy.new(layer).public_cache_eligible?
        attributes[:public_data] = eligible if layer.layer_provider == "martin" && layer.security_provenance != "explicit"
        layer.update_columns(attributes) if attributes.any?
        invalidate!(layer, reason: reason, previous_version: previous) if rotate
      end
    end
  end
end
