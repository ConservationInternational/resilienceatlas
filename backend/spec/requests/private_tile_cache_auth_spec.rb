require "rails_helper"

RSpec.describe "Private tile cache authorization", type: :request do
  let(:viewer_scope) { create(:site_scope) }
  let(:other_scope) { create(:site_scope) }
  let(:source_url) { "https://storage.googleapis.com/private-bucket/private.tif" }

  before do
    group = create(:layer_group, site_scope: other_scope)
    layer = create(:layer, published: true, layer_provider: "cog",
      layer_config: {body: {source: source_url}}.to_json)
    create(:agrupation, layer: layer, layer_group: group)
    host! "#{viewer_scope.subdomain}.example.org"
  end

  it "rejects a protected COG tile request before consulting an origin-cache hit" do
    expect(TileByteCache).not_to receive(:fetch)
    get "/api/titiler/tiles/0/0/0", params: {
      titilerUrl: "https://titiler.resilienceatlas.org",
      cogUrl: source_url
    }

    expect(response).to have_http_status(:forbidden)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "does not expose restricted data from an unprotected scope" do
    expect(TileByteCache).not_to receive(:fetch)
    group = create(:layer_group, site_scope: viewer_scope)
    restricted = create(:layer, published: true, layer_provider: "cog", data_policy: "restricted",
      layer_config: {body: {source: source_url}}.to_json)
    create(:agrupation, layer: restricted, layer_group: group)

    get "/api/titiler/tiles/0/0/0", params: {
      titilerUrl: "https://titiler.resilienceatlas.org",
      cogUrl: source_url
    }

    expect(response).to have_http_status(:forbidden)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "rechecks scope membership before returning a warmed private origin cache entry" do
    group = create(:layer_group, site_scope: viewer_scope)
    layer = create(:layer, published: true, layer_provider: "cog",
      layer_config: {body: {source: source_url}}.to_json)
    create(:agrupation, layer: layer, layer_group: group)
    cache = {}
    allow(TileByteCache).to receive(:fetch) do |key, **_options, &render|
      cache[key] ||= render.call
    end
    tile = TileRendererService::Result.new(status: 200, body: "cached-image", content_type: "image/png")
    allow(TileRendererService).to receive(:render_cog_source).and_return(tile)

    get "/api/titiler/tiles/0/0/0", params: {
      titilerUrl: "https://titiler.resilienceatlas.org",
      cogUrl: source_url
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("cached-image")
    expect(TileByteCache).to have_received(:fetch).once

    group.layers.delete(layer)
    get "/api/titiler/tiles/0/0/0", params: {
      titilerUrl: "https://titiler.resilienceatlas.org",
      cogUrl: source_url
    }

    expect(response).to have_http_status(:forbidden)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(TileByteCache).to have_received(:fetch).once
  end
end
