require "rails_helper"

RSpec.describe "Policy-sensitive tile catalogue", type: :request do
  let!(:scope) { create(:site_scope) }
  let!(:group) { create(:layer_group, site_scope: scope) }
  let!(:layer) { create(:layer, layer_provider: "wmts", layer_groups: [group]) }

  it "does not share-cache an unversioned catalogue across a confidentiality change" do
    get "/api/layers", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to include(layer.id.to_s)
    expect(response.headers["Cache-Control"]).to include("private", "no-store")

    layer.update!(data_policy: "restricted", security_provenance: "explicit")
    get "/api/layers", params: {site_scope: scope.subdomain}
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).not_to include(layer.id.to_s)
    expect(response.headers["Cache-Control"]).to include("private", "no-store")
  end
end
