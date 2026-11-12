require "rails_helper"

RSpec.describe "Public tile route", type: :request do
  let(:layer) do
    create(:layer, layer_provider: "martin",
      layer_config: {body: {source: "public_table"}}.to_json)
  end
  let(:tile) do
    TileRendererService::Result.new(
      status: 200,
      body: "vector-tile",
      content_type: "application/vnd.mapbox-vector-tile"
    )
  end

  before do
    host! "tiles.example.org"
    allow_any_instance_of(TileSecurityPolicy).to receive(:public_cache_eligible?).and_return(true)
    allow_any_instance_of(TileSecurityPolicy).to receive(:version).and_return("generation-1")
    allow_any_instance_of(TileSecurityPolicy).to receive(:source_key).and_return("source-digest")
    allow(TileByteCache).to receive(:fetch) { |_key, **_options, &block| block.call }
  end

  it "renders the saved layer representation and gives only successful tiles a shared cache header" do
    expect(TileRendererService).to receive(:render).with(layer, z: 0, x: 0, y: 0, params: {}).and_return(tile)

    get "/api/public-tiles/#{layer.id}/generation-1/0/0/0"

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("vector-tile")
    expect(response.headers["Cache-Control"]).to include("public", "max-age=0", "s-maxage=86400")
    expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  end

  it "does not render a stale generation" do
    expect(TileRendererService).not_to receive(:render)

    get "/api/public-tiles/#{layer.id}/old-generation/0/0/0"

    expect(response).to have_http_status(:not_found)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "does not serve a layer that is no longer public-cache eligible" do
    allow_any_instance_of(TileSecurityPolicy).to receive(:public_cache_eligible?).and_return(false)
    expect(TileRendererService).not_to receive(:render)

    get "/api/public-tiles/#{layer.id}/generation-1/0/0/0"

    expect(response).to have_http_status(:not_found)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "does not cache upstream failures" do
    failed = TileRendererService::Result.new(status: 502, body: '{"error":"failed"}', content_type: "application/json")
    allow(TileRendererService).to receive(:render).and_return(failed)

    get "/api/public-tiles/#{layer.id}/generation-1/0/0/0"

    expect(response).to have_http_status(:bad_gateway)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "rejects arbitrary query variants" do
    expect(TileRendererService).not_to receive(:render)

    get "/api/public-tiles/#{layer.id}/generation-1/0/0/0?url=https://attacker.example/file.tif"

    expect(response).to have_http_status(:bad_request)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  it "publishes timeline COG routes only for date-templated saved sources" do
    temporal = create(:layer, layer_provider: "cog", timeline: true,
      layer_config: {
        body: {source: "https://storage.googleapis.com/public-data/ndvi-{{year}}-{{month}}-{{day}}.tif"}
      }.to_json)
    mixed = create(:layer, layer_provider: "cog", timeline: true,
      layer_config: {
        body: {
          sources: [
            "https://storage.googleapis.com/public-data/ndvi-{{year}}-{{month}}-{{day}}.tif",
            "https://storage.googleapis.com/public-data/static.tif"
          ]
        }
      }.to_json)

    temporal_config = JSON.parse(LayerSerializer.new(temporal).layer_config)
    mixed_config = JSON.parse(LayerSerializer.new(mixed).layer_config)

    expect(temporal_config.dig("body", "public_tile_url")).to include(
      "/api/public-tiles/#{temporal.id}/", "?time={{year}}-{{month}}-{{day}}"
    )
    expect(mixed_config.dig("body", "public_tile_url")).to be_nil
  end

  it "keeps runtime COG style substitutions on the authorized gateway" do
    styled = create(:layer, layer_provider: "cog",
      layer_config: {
        params: {rescale: "0,{{max_value}}"},
        body: {source: "https://storage.googleapis.com/public-data/ndvi.tif"}
      }.to_json)

    config = JSON.parse(LayerSerializer.new(styled).layer_config)

    expect(config.dig("body", "public_tile_url")).to be_nil
  end

  it "binds an allowed timeline date to the saved temporal source" do
    temporal = create(:layer, layer_provider: "cog", timeline: true,
      layer_config: {
        body: {source: "https://storage.googleapis.com/public-data/ndvi-{{year}}-{{month}}-{{day}}.tif"}
      }.to_json)
    expect(TileRendererService).to receive(:render).with(
      temporal, z: 0, x: 0, y: 0, params: {"time" => "2024-01-01"}
    ).and_return(tile)

    get "/api/public-tiles/#{temporal.id}/generation-1/0/0/0", params: {time: "2024-01-01"}

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to include("s-maxage=86400")
  end

  it "does not silently ignore a time variant for a static COG source" do
    static = create(:layer, layer_provider: "cog",
      layer_config: {body: {source: "https://storage.googleapis.com/public-data/ndvi.tif"}}.to_json)

    get "/api/public-tiles/#{static.id}/generation-1/0/0/0", params: {time: "2024-01-01"}

    expect(response).to have_http_status(:not_found)
    expect(response.headers["Cache-Control"]).to include("no-store")
  end
end
