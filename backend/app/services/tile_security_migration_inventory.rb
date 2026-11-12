class TileSecurityMigrationInventory
  def self.call
    connection = Layer.connection
    restricted = ENV.fetch("TILE_SECURITY_RESTRICTED_LAYER_IDS", "").split(",").reject(&:empty?).map { |id| Integer(id, 10) }
    rows = connection.select_all(<<~SQL).to_a
      SELECT l.id, l.published, l.layer_provider,
        EXISTS (SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id=a.layer_group_id
          JOIN site_scopes s ON s.id=g.site_scope_id WHERE a.layer_id=l.id AND NOT s.password_protected) AS public_scope,
        EXISTS (SELECT 1 FROM agrupations a JOIN layer_groups g ON g.id=a.layer_group_id
          JOIN site_scopes s ON s.id=g.site_scope_id WHERE a.layer_id=l.id AND s.password_protected) AS protected_scope
      FROM layers l ORDER BY l.id
    SQL
    groups = rows.group_by do |row|
      [row["layer_provider"], row["published"], row["public_scope"], row["protected_scope"], restricted.include?(row["id"])]
    end.map do |(provider, published, public_scope, protected_scope, denied), members|
      {"provider" => provider, "published" => published, "public_scope" => public_scope, "protected_scope" => protected_scope,
       "manifest_restricted" => denied, "count" => members.size, "layer_ids" => members.map { |row| row["id"] },
       "grandfather_public_intent" => published && public_scope && !denied,
       "direct_martin_candidate" => provider == "martin" && published && public_scope && !protected_scope && !denied}
    end
    {"dry_run" => true, "cutoff" => "20261112090000", "evidence" => "local_configuration_only",
     "groups" => groups, "unknown_manifest_ids" => restricted - rows.map { |row| row["id"] },
     "limitations" => [
       "Historical false approvals have no revocation provenance",
       "Direct Martin candidates still require source-wide alias validation; this inventory does not approve access"
     ]}
  end
end
