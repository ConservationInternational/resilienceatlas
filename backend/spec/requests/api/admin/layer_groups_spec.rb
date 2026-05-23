require "rails_helper"

RSpec.describe "API Admin Layer Groups", type: :request do
  let(:token) { "SECRET_API_KEY" }
  let(:headers) { {"Authorization" => "Bearer #{token}"} }

  before { stub_const("ENV", ENV.to_hash.merge("RESILIENCE_API_KEY" => token)) }

  describe "GET /api/admin/layer_groups" do
    it "lists layer groups for a site scope" do
      site_scope = create(:site_scope)
      matching_group = create(:layer_group, site_scope: site_scope, name: "Ecoregions")
      create(:layer_group)

      get "/api/admin/layer_groups", params: {site_scope_id: site_scope.id}, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_json["success"]).to eq(true)
      expect(response_json["data"].map { |group| group["id"] }).to eq([matching_group.id])
      expect(response_json["data"].first["name"]).to eq("Ecoregions")
    end
  end

  describe "POST /api/admin/layer_groups" do
    it "creates a new top-level category for a site scope" do
      site_scope = create(:site_scope)

      post "/api/admin/layer_groups",
        params: {
          layer_group: {
            site_scope_id: site_scope.id,
            name: "Ecoregions",
            layer_group_type: "category"
          }
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:ok)
      expect(response_json["success"]).to eq(true)
      expect(response_json["data"]["name"]).to eq("Ecoregions")
      expect(response_json["data"]["slug"]).to eq("ecoregions")
      expect(response_json["data"]["site_scope_id"]).to eq(site_scope.id)
      expect(LayerGroup.find(response_json["data"]["id"]).layer_group_type).to eq("category")
    end
  end
end