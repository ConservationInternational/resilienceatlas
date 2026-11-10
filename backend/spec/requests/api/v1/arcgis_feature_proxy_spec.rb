require "rails_helper"

RSpec.describe "ArcGIS feature proxy", type: :request do
  let(:arcgis_url) { "https://services.arcgis.com/example/arcgis/rest/services/Roads/FeatureServer/0" }
  let(:body) { {"url" => arcgis_url, "token" => "server-token"} }
  let(:layer) { create(:layer, layer_provider: "arcgis_feature", layer_config: {"body" => body}.to_json) }
  let(:endpoint) { "/api/arcgis-feature-proxy/#{layer.id}/query" }
  let(:features) { {"features" => []}.to_json }

  it "forwards the map client's geometry query and injects the configured token" do
    query = {
      "f" => "json",
      "where" => "status='active'",
      "geometry" => {"xmin" => 1, "ymin" => 2, "xmax" => 3, "ymax" => 4}.to_json,
      "geometryType" => "esriGeometryEnvelope",
      "inSR" => "3857",
      "outSR" => "3857",
      "outFields" => "*",
      "returnGeometry" => "true",
      "spatialRel" => "esriSpatialRelIntersects"
    }
    upstream = stub_request(:get, "#{arcgis_url}/query")
      .with(query: query.merge("token" => "server-token"))
      .to_return(status: 200, body: features, headers: {"Content-Type" => "application/json"})

    get endpoint, params: query

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("features" => [])
    expect(upstream).to have_been_requested.once
  end

  it "preserves pagination and JSON-encoded statistics parameters" do
    query = {
      "f" => "json",
      "resultOffset" => "100",
      "resultRecordCount" => "50",
      "orderByFields" => "name ASC",
      "groupByFieldsForStatistics" => "status",
      "outStatistics" => [{statisticType: "count", onStatisticField: "id", outStatisticFieldName: "total"}].to_json
    }
    upstream = stub_request(:get, "#{arcgis_url}/query")
      .with(query: query.merge("token" => "server-token"))
      .to_return(status: 200, body: features)

    get endpoint, params: query

    expect(response).to have_http_status(:ok)
    expect(upstream).to have_been_requested.once
  end

  it "does not forward unknown parameters or a caller-supplied token" do
    upstream = stub_request(:get, "#{arcgis_url}/query")
      .with(query: {"f" => "json", "token" => "server-token"})
      .to_return(status: 200, body: features)

    get endpoint, params: {f: "json", token: "client-token", unexpected: "value", layer: {published: false}}

    expect(response).to have_http_status(:ok)
    expect(upstream).to have_been_requested.once
  end

  it "does not forward nested hashes or arrays as scalar ArcGIS parameters" do
    upstream = stub_request(:get, "#{arcgis_url}/query")
      .with(query: {"f" => "json", "token" => "server-token"})
      .to_return(status: 200, body: features)

    get endpoint, params: {f: "json", where: {unexpected: "value"}, outFields: ["name"]}

    expect(response).to have_http_status(:ok)
    expect(upstream).to have_been_requested.once
  end

  it "allows public layers without forwarding a caller-supplied token" do
    body.delete("token")
    upstream = stub_request(:get, "#{arcgis_url}/query")
      .with(query: {"f" => "json"})
      .to_return(status: 200, body: features)

    get endpoint, params: {f: "json", token: "client-token"}

    expect(response).to have_http_status(:ok)
    expect(upstream).to have_been_requested.once
  end
end
