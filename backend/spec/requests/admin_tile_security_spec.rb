require "rails_helper"

RSpec.describe "Admin tile security", type: :request do
  let!(:scope) { create(:site_scope) }
  let!(:group) { create(:layer_group, site_scope: scope) }
  let!(:layer) { create(:layer, layer_provider: "martin", layer_config: {body: {source: "admin_security_points"}}.to_json) }
  let!(:admin) { create(:admin_user, role: :admin, allowed_site_scopes: [scope]) }
  let!(:superadmin) { create(:admin_user, role: :superadmin) }

  before { group.layers << layer }

  it "shows scoped readiness and exports only authorized records" do
    secret = create(:layer, slug: "unrelated-confidential-layer")
    sign_in admin
    expect(TileByteCache).not_to receive(:stats)
    get "/admin/tile_security"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(layer.slug)
    expect(response.body).not_to include(secret.slug)
    get "/admin/tile_security/export"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(layer.slug)
    expect(response.body).not_to include(secret.slug)
  end

  it "renders the layer security panel without exposing preview credentials" do
    sign_in admin
    get "/admin/layers/#{layer.id}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Tile security and cache readiness")
    expect(response.body).not_to include("admin_preview_token")
  end

  it "exposes aggregate cache health to superadmins" do
    sign_in superadmin
    expect(TileByteCache).to receive(:stats).and_call_original
    get "/admin/tile_security"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Private tile cache health", "Redis available", "Counters cover this Rails process only")
  end

  it "shows actionable redacted configuration diagnostics in the dashboard, layer panel and CSV" do
    layer.update_columns(layer_provider: "cog", layer_config: '{"body":{"source":"http://confidential.example/secret.tif?token=private-token"}}')
    sign_in admin
    ["/admin/tile_security", "/admin/layers/#{layer.id}", "/admin/tile_security/export"].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("unsupported_source_scheme", "COG sources must use s3:// or https://.")
    end
    expect(response.body).not_to include("confidential.example", "private-token")
  end

  it "filters verification evidence by the current generation, including exports" do
    TileSecurityVerification.create!(layer: layer, admin_user: admin, status: "passed",
      source_version: TileSecurityPolicy.new(layer.reload).version)
    sign_in admin
    get "/admin/tile_security", params: {status: "not_verified"}
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(layer.slug)
    layer.update!(tile_cache_version: SecureRandom.hex(16))
    get "/admin/tile_security/export", params: {status: "not_verified"}
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(layer.slug, "stale", "verified_at")
  end

  it "denies scoped admin policy overrides and contributor review writes" do
    sign_in admin
    post "/admin/layers/#{layer.id}/security_policy", params: {data_policy: "public", reason: "Override"}
    expect(response).not_to have_http_status(:ok)
    expect(TileSecurityEvent.where(action: "set_policy")).not_to exist
    sign_out admin
    contributor = create(:admin_user, role: :contributor, allowed_site_scopes: [scope])
    sign_in contributor
    post "/admin/layers/#{layer.id}/request_security_review", params: {reason: "Review"}
    expect(TileSecurityReview.count).to eq(0)
  end

  it "refreshes preview access only for a currently authorized resource" do
    sign_in admin
    post "/admin/layers/#{layer.id}/refresh_preview"
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.parsed_body.fetch("preview_query")).to include("admin_preview_token")
    admin.update!(allowed_site_scopes: [])
    post "/admin/layers/#{layer.id}/refresh_preview"
    expect(response).not_to have_http_status(:ok)
  end

  it "records a superadmin restriction using a reason" do
    sign_in superadmin
    post "/admin/layers/#{layer.id}/security_policy", params: {data_policy: "restricted", reason: "Confidential"}
    expect(response).to have_http_status(:redirect)
    expect(layer.reload.data_policy).to eq("restricted")
  end
end
