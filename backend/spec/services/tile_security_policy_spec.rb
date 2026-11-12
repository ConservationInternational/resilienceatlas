require "rails_helper"

RSpec.describe TileSecurityPolicy do
  def vector_layer(**attributes)
    create(:layer, {layer_provider: "martin", timeline: false,
                    layer_config: {"body" => {"source" => "ra_vector_tile", "params" => {"table" => "policy_test"}}}.to_json,
                    interaction_config: '{"output":[]}', published: true}.merge(attributes))
  end

  def attach_public(layer)
    create(:agrupation, layer: layer, layer_group: create(:layer_group))
    layer.reload
  end

  it "derives ordinary public Martin approval only after public scope assignment" do
    layer = vector_layer
    expect(layer).not_to be_public_data
    old_version = layer.tile_cache_version
    attach_public(layer)
    expect(described_class.new(layer)).to be_public_cache_eligible
    expect(layer).to be_public_data
    expect(layer.tile_cache_version).not_to eq(old_version)
  end

  it "does not publish drafts or grant restricted data public eligibility" do
    layer = attach_public(vector_layer(published: false, data_policy: "restricted"))
    expect(layer).not_to be_published
    expect(described_class.new(layer).report["reasons"]).to include("draft_not_published", "restricted_data_policy")
  end

  it "blocks all aliases for a restricted source without exposing its configuration" do
    layer = attach_public(vector_layer)
    alias_layer = attach_public(vector_layer(data_policy: "restricted"))
    report = described_class.new(layer.reload).report
    expect(report["reasons"]).to include("conflicting_source_alias")
    expect(report["source_key"]).to match(/\A[0-9a-f]{64}\z/)
    expect(report.to_json).not_to include("policy_test", alias_layer.slug)
    expect(layer.reload).not_to be_public_data
  end

  it "preserves explicit revocation across later edits and alias changes" do
    layer = attach_public(vector_layer)
    layer.update!(public_data: false)
    layer.update!(opacity: 0.4)
    create(:agrupation, layer: layer, layer_group: create(:layer_group))
    expect(layer.reload.security_provenance).to eq("explicit")
    expect(described_class.new(layer)).not_to be_public_cache_eligible
  end

  it "rotates policy on source and representation changes, not unrelated metadata" do
    layer = attach_public(vector_layer)
    old = layer.tile_cache_version
    layer.update!(description: "Metadata only")
    expect(layer.tile_cache_version).to eq(old)
    layer.update!(layer_config: '{"body":{"source":"another_table"}}')
    expect(layer.tile_cache_version).not_to eq(old)
  end

  it "blocks mixed protected membership and recomputes when a scope changes" do
    layer = attach_public(vector_layer)
    scope = layer.site_scopes.first
    old = layer.tile_cache_version
    scope.update!(password_protected: true, username: "viewer", encrypted_password: BCrypt::Password.create("password-for-test"))
    expect(layer.reload.tile_cache_version).not_to eq(old)
    expect(described_class.new(layer).report["reasons"]).to include("protected_membership_blocks_public_origin")
    expect(layer).not_to be_public_data
  end

  it "moves group scope and denies aliases of its source" do
    layer = attach_public(vector_layer)
    other = attach_public(vector_layer)
    scope = create(:site_scope, password_protected: true, username: "viewer", encrypted_password: BCrypt::Password.create("test-password"))
    layer.layer_groups.first.update!(site_scope: scope)
    expect(described_class.new(other.reload)).not_to be_public_cache_eligible
  end

  it "preserves explicit restrictions through cloning without reusing versions" do
    layer = vector_layer(data_policy: "restricted")
    copy = layer.clone!
    expect(copy.data_policy).to eq("restricted")
    expect(copy.tile_cache_version).not_to eq(layer.tile_cache_version)
  end

  it "canonicalizes signed COG aliases without persisting or displaying tokens" do
    first = vector_layer(layer_provider: "cog", layer_config: '{"body":{"source":"https://storage.example/data.tif?token=secret"}}')
    second = vector_layer(layer_provider: "cog", layer_config: '{"body":{"source":"https://storage.example/data.tif?token=another"}}')
    expect(described_class.new(first).source_key).to eq(described_class.new(second).source_key)
    expect(described_class.new(first).report.to_json).not_to include("secret", "storage.example")
  end

  it "fails closed for malformed source shapes and unresolved GEE assets" do
    layer = vector_layer
    layer.update_column(:layer_config, '{"body":{"params":"invalid"}}')
    expect(described_class.new(layer).report["reasons"]).to include("invalid_provider_config")
    layer.update_columns(layer_provider: "gee", layer_config: '{"body":{"url":"https://ee.example/tiles"}}', analysis_body: nil)
    expect(described_class.new(layer)).not_to be_public_cache_eligible
  end

  it "blocks invalid publication transitions but permits emergency unpublishing" do
    layer = vector_layer(published: false, layer_config: "{}")
    expect(layer.update(published: true)).to be(false)
    layer.update_columns(published: true)
    expect(layer.update(published: false)).to be(true)
  end

  it "offers batch reports with global aliases kept server-side" do
    layer = attach_public(vector_layer)
    attach_public(vector_layer(data_policy: "restricted"))
    report = described_class.reports_for([layer]).fetch(layer.id)
    expect(report).to eq(described_class.new(layer).report)
    expect(report.to_json).not_to include("policy_test", "layer_config")
  end

  it "reports an unconfigured shared CDN as a warning without revoking eligible origin tiles" do
    layer = attach_public(vector_layer)
    stub_const("ENV", ENV.to_h.except("TILE_PUBLIC_CDN_URL"))
    report = described_class.new(layer).report
    expect(report).to include("status" => "warning", "public_cache_eligible" => true)
    expect(report["reasons"]).to include("cache_route_not_active")
    ENV["TILE_PUBLIC_CDN_URL"] = "https://tiles.example.test"
    expect(described_class.new(layer).report["reasons"]).not_to include("cache_route_not_active")
  end

  it "reports public alias exposure without revealing the alias identity or blocking ordinary aliases" do
    layer = attach_public(vector_layer)
    other = attach_public(vector_layer)
    report = described_class.new(layer).report
    expect(report["reasons"]).to include("shared_source_public_alias")
    expect(report["public_cache_eligible"]).to be(true)
    expect(report.to_json).not_to include(other.slug)
  end

  it "reports failed source activation distinctly from normal import staging" do
    layer = attach_public(vector_layer)
    record = TileSourceImport.create!(run_id: SecureRandom.uuid, operation: "failed-source",
      fingerprint: "changed-manifest", identity: "operator:test", layer_ids: [layer.id], status: "reconciliation_required")
    expect(described_class.new(layer).report["reasons"]).to include("source_changed_review_required", "import_security_reconciliation_failed")
    record.update!(status: "staged")
    expect(described_class.new(layer).report["reasons"]).not_to include("import_security_reconciliation_failed")
  end

  it "rejects malformed supported source edits on already published layers" do
    layer = vector_layer
    expect(layer.update(layer_config: "{}")).to be(false)
    expect(layer.reload.layer_config).to include("policy_test")
  end

  it "does not mistake valid unsupported XYZ and WMTS providers for malformed sources" do
    %w[wmts xyz\ tileset].each do |provider|
      layer = vector_layer(published: false, layer_provider: provider,
        layer_config: '{"body":{"url":"https://external.example/{z}/{x}/{y}.png"}}')
      expect(layer.update(published: true)).to be(true)
      expect(described_class.new(layer).report["reasons"]).to include("unsupported_provider")
      expect(described_class.new(layer).report["reasons"]).not_to include("invalid_provider_config")
    end
  end

  it "accepts existing saved Earth Engine map URLs without an asset query or leaking map tokens" do
    layer = vector_layer(published: false, layer_provider: "gee", analysis_body: "{}",
      layer_config: '{"body":{"url":"https://earthengine.googleapis.com/v1/projects/test/maps/map123/tiles/{z}/{x}/{y}?token=private-map-token"}}')
    expect(layer.update(published: true)).to be(true)
    expect(described_class.new(layer).report.to_json).not_to include("private-map-token")
    expect(described_class.new(layer).source_key).to match(/\A[0-9a-f]{64}\z/)
  end

  it "excludes restricted public layers and their public aliases from the shared serving finder" do
    layer = attach_public(vector_layer)
    scope = layer.site_scopes.first
    expect(Layer.fetch_all(site_scope: scope.id)).to include(layer)
    restricted_alias = vector_layer(data_policy: "restricted", published: false)
    expect(Layer.fetch_all(site_scope: scope.id)).not_to include(layer)
    restricted_alias.destroy!
    expect(Layer.fetch_all(site_scope: scope.id)).to include(layer)
    layer.update!(data_policy: "restricted")
    expect(Layer.fetch_all(site_scope: scope.id)).not_to include(layer)
  end

  it "keeps protected-scope credential and actor-bound preview paths separate from public filtering" do
    layer = vector_layer(data_policy: "restricted")
    scope = create(:site_scope, password_protected: true, username: "viewer", encrypted_password: BCrypt::Password.create("test-password"))
    create(:agrupation, layer: layer, layer_group: create(:layer_group, site_scope: scope))
    expect(Layer.fetch_all(site_scope: scope.id)).to include(layer)
    expect(Layer.find(layer.id)).to eq(layer)
  end
end
