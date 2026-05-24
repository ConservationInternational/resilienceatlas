require "rails_helper"

RSpec.describe "API Admin Layer Assignments", type: :request do
  let(:token) { "SECRET_API_KEY" }
  let(:headers) { {"Authorization" => "Bearer #{token}"} }

  before { stub_const("ENV", ENV.to_hash.merge("RESILIENCE_API_KEY" => token)) }

  it "links a created layer to the requested layer group from the nested layer payload" do
    site_scope = create(:site_scope)
    layer_group = create(:layer_group, site_scope: site_scope, name: "Ecoregions", slug: "ecoregions")
    layer_attrs = build(:layer).attributes.slice(
      "name",
      "slug",
      "layer_provider",
      "interaction_config",
      "layer_config",
      "zoom_min",
      "zoom_max"
    ).merge("layer_group_id" => layer_group.id)

    post "/api/admin/layers",
      params: {
        site_scope_id: site_scope.id,
        layer: layer_attrs
      },
      headers: headers,
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response_json["success"]).to eq(true)

    created_layer = Layer.find(response_json["data"]["id"])
    expect(created_layer.layer_groups).to include(layer_group)
    expect(created_layer.layer_groups.where(name: "New uploads")).to be_empty
  end
end
