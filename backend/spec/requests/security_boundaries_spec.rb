require "rails_helper"

RSpec.describe "Security boundaries", type: :request do
  before(:context) do
    require Rails.root.join("db/migrate/20261111143000_secure_public_tile_sources")
    SecurePublicTileSources.new.install_tile_functions
    require Rails.root.join("db/migrate/20261112090000_add_tile_security_policy")
    AddTileSecurityPolicy.new.install_public_guard
    ActiveRecord::Base.connection.execute("CREATE SCHEMA IF NOT EXISTS ra_vector")
    ActiveRecord::Base.connection.execute("CREATE TABLE ra_vector.security_test_points (id integer, geom geometry(Point,4326))")
    ActiveRecord::Base.connection.execute("INSERT INTO ra_vector.security_test_points VALUES (1, ST_SetSRID(ST_MakePoint(0,0),4326))")
  end

  after(:context) do
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS ra_vector.security_test_points")
  end
  let!(:scope) { create(:site_scope) }
  let!(:other_scope) { create(:site_scope, :password_protected) }
  let!(:group) { create(:layer_group, site_scope: scope) }
  let!(:other_group) { create(:layer_group, site_scope: other_scope) }
  let!(:layer) { create(:layer, published: true, layer_provider: "martin", layer_config: {body: {source: "ra_vector_tile", params: {table: "security_test_points"}}}.to_json) }
  let!(:other_layer) { create(:layer, published: true) }
  let!(:admin) { create(:admin_user, role: :admin, allowed_site_scopes: [scope]) }
  let!(:contributor) { create(:admin_user, role: :contributor, allowed_site_scopes: [scope]) }
  let!(:superadmin) { create(:admin_user, role: :superadmin) }
  let(:headers) { {"Authorization" => "Bearer security-test-key", "X-Admin-User-Id" => admin.id.to_s} }

  before do
    stub_const("ENV", ENV.to_h.merge("RESILIENCE_API_KEY" => "security-test-key"))
    group.layers << layer
    other_group.layers << other_layer
  end

  it "requires a real actor as well as a service credential" do
    get "/api/admin/layers", headers: headers.except("X-Admin-User-Id")
    expect(response).to have_http_status(:unauthorized)
    get "/api/admin/layers", headers: headers.except("Authorization")
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists only layers fully within the actor's assigned scopes" do
    get "/api/admin/layers", headers: headers
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([layer.id])
    other_group.layers << layer
    get "/api/admin/layers", headers: headers
    expect(response.parsed_body.fetch("data")).to be_empty
  end

  it "denies scoped admins cross-scope updates and superadmin account changes" do
    patch "/api/admin/layers/#{other_layer.id}", params: {layer: {published: false}}, headers: headers, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(Ability.new(admin).can?(:update, superadmin)).to be false
    expect(Ability.new(admin).can?(:update, admin)).to be true
  end

  it "allows admins to update assigned layers and revokes public data approval" do
    layer.update!(public_data: true)
    patch "/api/admin/layers/#{layer.id}", params: {layer: {published: false}}, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(layer.reload.published).to be false
    expect(layer.public_data).to be false
  end

  [true, "true", "1"].each do |published|
    it "forces contributor creation to unpublished for #{published.inspect}" do
      attrs = build(:layer).attributes.except("id", "created_at", "updated_at").merge("published" => published)
      post "/api/admin/layers", params: {layer: attrs, site_scope_id: scope.id},
        headers: headers.merge("X-Admin-User-Id" => contributor.id.to_s), as: :json
      expect(response).to have_http_status(:ok)
      created = Layer.find(response.parsed_body.fetch("data").fetch("id"))
      expect(created.published).to be false
      expect(created.site_scope_ids).to eq([scope.id])
    end
  end

  it "denies every contributor update, delete, unscoped creation and cross-scope creation" do
    actor_headers = headers.merge("X-Admin-User-Id" => contributor.id.to_s)
    patch "/api/admin/layers/#{layer.id}", params: {layer: {published: "true"}}, headers: actor_headers, as: :json
    expect(response).to have_http_status(:forbidden)
    delete "/api/admin/layers/#{layer.id}", headers: actor_headers
    expect(response).to have_http_status(:forbidden)
    post "/api/admin/layers", params: {layer: {slug: "forbidden"}}, headers: actor_headers, as: :json
    expect(response).to have_http_status(:forbidden)
    post "/api/admin/layers", params: {layer: {slug: "forbidden"}, site_scope_id: other_scope.id}, headers: actor_headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "disables API SQL execution even for a superadmin" do
    post "/api/admin/vector_views", params: {name: "v_steal", sql: 'SELECT * FROM "ra_app"."admin_users"'},
      headers: headers.merge("X-Admin-User-Id" => superadmin.id.to_s), as: :json
    expect(response).to have_http_status(:forbidden)
    get "/api/admin/vector_tables", headers: headers
    expect(response).to have_http_status(:forbidden)
  end

  it "redacts stored ArcGIS credentials in admin API responses" do
    layer.update!(layer_provider: "arcgis_feature", layer_config: {body: {url: "https://services.arcgis.com/test/FeatureServer/0", token: "synthetic-secret"}}.to_json)
    get "/api/admin/layers/#{layer.id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("synthetic-secret")
  end

  it "requires authentication on every protected data surface" do
    %w[layers layer-groups scope-datasets models indicators categories].each do |endpoint|
      get "/api/#{endpoint}", params: {site_scope: other_scope.subdomain}
      expect(response).to have_http_status(:unauthorized), endpoint
      expect(response.headers["Cache-Control"]).to include("no-store"), endpoint
    end
  end

  it "accepts explicit numeric scope IDs without falling back to another scope" do
    get "/api/models", params: {site_scope: other_scope.id}
    expect(response).to have_http_status(:unauthorized)
    get "/api/models", params: {site_scope: "unknown-security-scope"}
    expect(response).to have_http_status(:not_found)
  end

  it "preserves no-store after successful protected catalogue responses" do
    token = JWT.encode({site_scope_id: other_scope.id, exp: 1.hour.from_now.to_i}, Rails.application.secret_key_base, "HS256")
    %w[layers layer-groups scope-datasets models indicators categories].each do |endpoint|
      get "/api/#{endpoint}", params: {site_scope: other_scope.subdomain}, headers: {"Site-Scope-Token" => token}
      expect(response).to have_http_status(:ok), endpoint
      expect(response.headers["Cache-Control"]).to include("no-store"), endpoint
      expect(response.headers["Cache-Control"]).not_to include("public"), endpoint
    end
  end

  it "does not lend an ArcGIS credential to other scopes or expose drafts" do
    other_layer.update!(layer_provider: "arcgis_feature")
    get "/api/arcgis-feature-proxy/#{other_layer.id}/query", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:not_found)
    layer.update!(published: false, layer_provider: "arcgis_feature")
    get "/api/arcgis-feature-proxy/#{layer.id}/query", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:not_found)
  end

  it "rejects arbitrary raster sources before any upstream request" do
    get "/api/titiler/info", params: {site_scope: scope.subdomain, cogUrl: "s3://resilienceatlas/secret.tif", titilerUrl: "http://localhost:3001"}
    expect(response).to have_http_status(:forbidden)
  end

  it "serves authorized vector tiles but denies drafts and unrelated scopes" do
    get "/api/layers/#{layer.id}/tiles/0/0/0", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:ok)
    expect(response.body.bytesize).to be > 0
    expect(response.media_type).to eq("application/vnd.mapbox-vector-tile")
    get "/api/layers/#{layer.id}/tiles/0/0/0", params: {site_scope: other_scope.subdomain}
    expect(response).to have_http_status(:unauthorized)
    layer.update!(published: false)
    get "/api/layers/#{layer.id}/tiles/0/0/0", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:not_found)
  end

  it "derives public access, preserves explicit revocation and protects restricted aliases" do
    sql = "SELECT public.ra_vector_tile(0,0,0,'{\"table\":\"security_test_points\"}'::json)"
    TilePolicyLifecycle.refresh!([layer], reason: "security_boundary_test")
    expect(layer.reload.public_data).to be true
    expect(ActiveRecord::Base.connection.select_value(sql).bytesize).to be > 0

    layer.update!(public_data: false)
    expect(layer.reload.security_provenance).to eq("explicit")
    expect {
      ActiveRecord::Base.transaction(requires_new: true) { ActiveRecord::Base.connection.select_value(sql) }
    }.to raise_error(ActiveRecord::StatementInvalid, /not approved/)
    layer.update!(public_data: true)
    expect(ActiveRecord::Base.connection.select_value(sql).bytesize).to be > 0

    restricted_alias = create(:layer, published: true, layer_provider: "martin", data_policy: "restricted",
      layer_config: {body: {source: "ra_vector_tile", params: {table: "security_test_points"}}}.to_json)
    other_group.layers << restricted_alias
    TilePolicyLifecycle.refresh!([layer, restricted_alias], reason: "security_boundary_alias_test")
    expect {
      ActiveRecord::Base.transaction(requires_new: true) { ActiveRecord::Base.connection.select_value(sql) }
    }.to raise_error(ActiveRecord::StatementInvalid, /not approved/)

    restricted_alias.destroy!
    TilePolicyLifecycle.refresh!([layer], reason: "security_boundary_alias_removed")
    layer.update!(public_data: true)
    expect(ActiveRecord::Base.connection.select_value(sql).bytesize).to be > 0

    other_group.layers << layer
    expect {
      ActiveRecord::Base.transaction(requires_new: true) { ActiveRecord::Base.connection.select_value(sql) }
    }.to raise_error(ActiveRecord::StatementInvalid, /not approved/)
  end

  it "binds short-lived draft preview access to the layer and current permissions" do
    layer.update!(published: false)
    token = AdminPreviewAccess.issue(layer, admin)
    get "/api/layers/#{layer.id}/tiles/0/0/0", params: {site_scope: scope.subdomain, admin_preview_token: token}
    expect(response).to have_http_status(:ok)
    admin.allowed_site_scopes.clear
    get "/api/layers/#{layer.id}/tiles/0/0/0", params: {site_scope: scope.subdomain, admin_preview_token: token}
    expect(response).to have_http_status(:not_found)
  end

  it "renders the authorized admin editor with handshake-only preview configuration" do
    sign_in admin
    get "/admin/layers/#{layer.id}/edit"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("LAYER_PREVIEW_READY", "data-preview-query=")
    expect(response.body).not_to include("/admin-preview/layer?data=")
  end

  it "does not allow a scoped admin to elevate their own account" do
    sign_in admin
    patch "/admin/admin_users/#{admin.id}", params: {admin_user: {role: "superadmin", allowed_site_scope_ids: [other_scope.id]}}
    expect(admin.reload).not_to be_superadmin
    expect(admin.allowed_site_scope_ids).to eq([scope.id])
  end

  it "does not allow nested layer assignments or parent changes outside assigned scopes" do
    sign_in admin
    patch "/admin/layer_groups/#{group.id}", params: {layer_group: {
      site_scope_id: other_scope.id,
      agrupations_attributes: {"0" => {layer_id: other_layer.id}}
    }}
    expect(group.reload.site_scope_id).to eq(scope.id)
    expect(group.layers).not_to include(other_layer)
  end

  it "enforces scope and publication on GEE tiles without exposing the upstream map token" do
    upstream_url = "https://earthengine.googleapis.com/v1/projects/test/maps/map/tiles/{z}/{x}/{y}?token=synthetic-map-token"
    layer.update!(layer_provider: "gee", layer_config: {body: {url: upstream_url}}.to_json)
    serialized = JSON.parse(LayerSerializer.new(layer).layer_config)
    expect(serialized.dig("body", "url")).to eq("/api/earth-engine/tiles/#{layer.id}/{z}/{x}/{y}")
    expect(serialized.to_json).not_to include("synthetic-map-token")
    upstream = stub_request(:get, upstream_url.gsub("{z}", "0").gsub("{x}", "0").gsub("{y}", "0"))
      .to_return(status: 200, body: "\x89PNG".b)
    get "/api/earth-engine/tiles/#{layer.id}/0/0/0", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(upstream).to have_been_requested.once
    get "/api/earth-engine/tiles/#{layer.id}/0/0/0", params: {site_scope: other_scope.subdomain}
    expect(response).to have_http_status(:unauthorized)
    layer.update!(published: false)
    get "/api/earth-engine/tiles/#{layer.id}/0/0/0", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:not_found)
  end

  it "binds Earth Engine operation signatures to the published asset and rejects method confusion" do
    stub_const("ENV", ENV.to_h.merge("DATA_GATEWAY_SECRET" => "s" * 32, "EARTH_ENGINE_API_URL" => "https://ee.resilienceatlas.org"))
    layer.update!(layer_provider: "gee", analysis_body: {assetId: "private/asset"}.to_json)
    upstream = stub_request(:post, "https://ee.resilienceatlas.org/histogram")
      .with(body: {assetId: "private/asset", geometry: {type: "Polygon", coordinates: []}},
        headers: {"X-Data-Authorization" => /\A\d+:[a-f0-9]{64}\z/})
      .to_return(body: '{"rows":[]}', headers: {"Content-Type" => "application/json"})
    post "/api/earth-engine/histogram?site_scope=#{scope.subdomain}&layer_id=#{layer.id}&assetId=private%2Fasset",
      params: {geometry: {type: "Polygon", coordinates: []}}, as: :json
    expect(response).to have_http_status(:ok)
    expect(upstream).to have_been_requested.once
    get "/api/earth-engine/histogram", params: {site_scope: scope.subdomain, layer_id: layer.id, assetId: "private/asset"}
    expect(response).to have_http_status(:method_not_allowed)
    post "/api/earth-engine/histogram", params: {site_scope: scope.subdomain, layer_id: layer.id, assetId: "private/other"}, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "enforces CSRF on session-authenticated admin mutations" do
    sign_in admin
    previous = Admin::AiChatController.allow_forgery_protection
    begin
      Admin::AiChatController.allow_forgery_protection = true
      post "/admin/ai_chat/reset", params: {}, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    ensure
      Admin::AiChatController.allow_forgery_protection = previous
    end
  end
end
