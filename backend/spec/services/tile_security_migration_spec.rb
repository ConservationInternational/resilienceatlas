require "rails_helper"
require Rails.root.join("db/migrate/20261112090000_add_tile_security_policy")

RSpec.describe AddTileSecurityPolicy do
  it "provides a read-only redacted manifest inventory without changing approval or versions" do
    layer = create(:layer, published: false, timeline: false, layer_provider: "wmts")
    stub_const("ENV", ENV.to_h.merge("TILE_SECURITY_RESTRICTED_LAYER_IDS" => layer.id.to_s))
    before = layer.attributes
    result = TileSecurityMigrationInventory.call
    expect(result).to include("dry_run" => true, "unknown_manifest_ids" => [])
    expect(result["groups"]).to include(include("layer_ids" => [layer.id], "manifest_restricted" => true, "grandfather_public_intent" => false))
    expect(layer.reload.attributes).to eq(before)
    expect(result.to_json).not_to include("layer_config", "encrypted_password")
  end

  it "grandfathers only public published intent and preserves drafts, protection and manifest denials" do
    connection = Layer.connection
    original_path = connection.schema_search_path
    schema = "tile_migration_#{SecureRandom.hex(6)}"
    connection.transaction(requires_new: true) do
      connection.execute("CREATE SCHEMA #{schema}")
      connection.schema_search_path = "#{schema},public"
      connection.execute("CREATE TABLE layers (id bigint PRIMARY KEY, published boolean, layer_provider text, layer_config text, public_data boolean DEFAULT false)")
      connection.execute("CREATE TABLE site_scopes (id bigint PRIMARY KEY, password_protected boolean)")
      connection.execute("CREATE TABLE layer_groups (id bigint PRIMARY KEY, site_scope_id bigint)")
      connection.execute("CREATE TABLE agrupations (layer_id bigint, layer_group_id bigint)")
      connection.execute("INSERT INTO site_scopes VALUES (1,false),(2,true)")
      connection.execute("INSERT INTO layer_groups VALUES (1,1),(2,2)")
      connection.execute(<<~SQL)
        INSERT INTO layers (id,published,layer_provider,layer_config) VALUES
          (1,true,'martin','{"source":"public_table"}'),
          (2,false,'martin','{"source":"draft_table"}'),
          (3,true,'martin','{"source":"protected_table"}'),
          (4,true,'martin','{"source":"mixed_table"}'),
          (5,true,'martin','{"source":"revoked_table"}'),
          (6,true,'cog','{"body":{"source":"https://example.test/data.tif"}}'),
          (7,true,'martin','{"source":"orphan_table"}')
      SQL
      connection.execute("INSERT INTO agrupations VALUES (1,1),(2,1),(3,2),(4,1),(4,2),(5,1),(6,1)")
      stub_const("ENV", ENV.to_h.merge("TILE_SECURITY_RESTRICTED_LAYER_IDS" => "5"))
      ActiveRecord::Migration.suppress_messages { described_class.new.up }
      rows = connection.select_all("SELECT * FROM layers ORDER BY id").to_a.index_by { |row| row["id"] }
      expect(rows[1]).to include("security_provenance" => "legacy_public", "public_data" => true, "published" => true)
      expect(rows[2]).to include("security_provenance" => "default_public", "public_data" => false, "published" => false)
      expect(rows[3]).to include("security_provenance" => "default_public", "public_data" => false)
      expect(rows[4]).to include("security_provenance" => "legacy_public", "public_data" => false)
      expect(rows[5]).to include("security_provenance" => "explicit", "data_policy" => "restricted", "public_data" => false)
      expect(rows[6]).to include("security_provenance" => "legacy_public", "public_data" => false)
      expect(rows[7]).to include("security_provenance" => "default_public", "public_data" => false)
      expect(rows.values.map { |row| row["tile_cache_version"] }).to all(match(/\A[0-9a-f]{32}\z/))
      expect(connection.select_value("SELECT count(*) FROM agrupations")).to eq(7)
      expect(connection.select_value("SELECT password_protected FROM site_scopes WHERE id=2")).to be(true)
      inventory = connection.select_value("SELECT summary::text FROM tile_source_imports WHERE operation='migration:grandfather'")
      expect(JSON.parse(inventory)).to include("explicit_restriction_count" => 1, "grandfathered_count" => 3)
      # Reinstalling the guard never replays the cutoff backfill or a later revocation.
      connection.execute("UPDATE layers SET public_data=false, security_provenance='explicit' WHERE id=1")
      ActiveRecord::Migration.suppress_messages { described_class.new.install_public_guard }
      expect(connection.select_value("SELECT public_data FROM layers WHERE id=1")).to be(false)
      raise ActiveRecord::Rollback
    end
  ensure
    connection.schema_search_path = original_path
  end
end
