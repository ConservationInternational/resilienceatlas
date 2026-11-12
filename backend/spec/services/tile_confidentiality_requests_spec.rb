require "rails_helper"

RSpec.describe "Shared layer confidentiality boundary", type: :request do
  let(:scope) { create(:site_scope) }
  let(:group) { create(:layer_group, site_scope: scope) }

  def layer_for(provider, config)
    layer = create(:layer, published: true, timeline: false, layer_provider: provider,
      layer_config: config.to_json, interaction_config: '{"output":[]}')
    create(:agrupation, layer: layer, layer_group: group)
    layer.reload
  end

  it "denies anonymous vector bytes through a public alias of a confidential source" do
    layer = layer_for("martin", {body: {source: "ra_vector_tile", params: {table: "confidential_points"}}})
    create(:layer, published: false, timeline: false, layer_provider: "martin",
      data_policy: "restricted", layer_config: layer.layer_config, interaction_config: '{"output":[]}')
    get "/api/layers/#{layer.id}/tiles/0/0/0", params: {site_scope: scope.id}
    expect(response).to have_http_status(:not_found)
    get "/api/layers", params: {site_scope: scope.id}
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["data"].map { |record| record["id"] }).not_to include(layer.id.to_s)
  end

  it "denies anonymous COG info through an otherwise public source alias" do
    layer = layer_for("cog", {body: {source: "https://storage.googleapis.com/example/confidential.tif"}})
    create(:layer, published: false, timeline: false, layer_provider: "cog",
      data_policy: "restricted", layer_config: layer.layer_config, interaction_config: '{"output":[]}')
    get "/api/titiler/info", params: {
      site_scope: scope.id, cogUrl: "https://storage.googleapis.com/example/confidential.tif",
      titilerUrl: "https://titiler.resilienceatlas.org"
    }
    expect(response).to have_http_status(:forbidden)
  end

  it "denies anonymous GEE bytes through a restricted public layer" do
    layer = layer_for("gee", {body: {url: "https://earthengine.googleapis.com/v1/projects/test/maps/map123/tiles/{z}/{x}/{y}?token=private-map-token"}})
    layer.update!(data_policy: "restricted")
    get "/api/earth-engine/tiles/#{layer.id}/0/0/0", params: {site_scope: scope.id}
    expect(response).to have_http_status(:not_found)
  end
end
