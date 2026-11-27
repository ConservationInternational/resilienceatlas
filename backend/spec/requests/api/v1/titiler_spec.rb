require "swagger_helper"

RSpec.describe "API V1 TiTiler Proxy", type: :request do
  let(:valid_titiler_url) { "https://titiler.resilienceatlas.org" }
  let(:staging_titiler_url) { "https://staging.titiler.resilienceatlas.org" }
  let(:invalid_titiler_url) { "https://malicious-server.com" }
  let(:cog_url) { "https://storage.googleapis.com/bucket/layer.tif" }
  let(:scope) { create(:site_scope) }

  before do
    host! "#{scope.subdomain}.example.org"
    stub_const("ENV", ENV.to_h.merge("DATA_GATEWAY_SECRET" => "test-gateway-secret-32-characters-long"))
    group = create(:layer_group, site_scope: scope)
    [cog_url, "s3://resilienceatlas/cogs/total_annual_rainfall.tif"].each do |source|
      layer = create(:layer, published: true, layer_provider: "cog",
        layer_config: {body: {url: "#{valid_titiler_url}/tiles/{z}/{x}/{y}?url=#{CGI.escape(source)}"}}.to_json)
      create(:agrupation, layer: layer, layer_group: group)
    end
  end

  it "serves an allowlisted LDN raster only after protected-scope authentication" do
    source = "s3://trends.earth-private/counterbalancing/JRC/TrendsEarth_LDN_2000-2023_JRC_ecoregion_net_change_by_unit.tif"
    stub_const("ENV", ENV.to_h.merge("COG_ALLOWED_S3_BUCKETS" => "resilienceatlas,trends.earth-private"))
    protected_scope = create(:site_scope, :password_protected)
    group = create(:layer_group, site_scope: protected_scope)
    create(:layer, layer_provider: "cog", layer_groups: [group], timeline: false,
      layer_config: {body: {source: source}}.to_json)
    png = "\x89PNG\r\n\x1a\n".b + "ldn tile"
    upstream = stub_request(:get, "#{staging_titiler_url}/tiles/WebMercatorQuad/3/5/3")
      .with(query: hash_including("url" => source, "nodata" => "-32768.0", "colormap_name" => "ra_net_change_v2")) do |request|
        expires, signature = request.headers.fetch("X-Data-Authorization").split(":", 2)
        expected = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("DATA_GATEWAY_SECRET"), "#{expires}\n#{source}")
        expires.to_i > Time.current.to_i && signature == expected
      end
      .to_return(status: 200, body: png, headers: {"Content-Type" => "image/png"})
    params = {site_scope: protected_scope.id, titilerUrl: staging_titiler_url, cogUrl: source,
              nodata: "-32768", colormap_name: "ra_net_change_v2"}
    get "/api/titiler/tiles/3/5/3", params: params
    expect(response).to have_http_status(:unauthorized)
    expect(upstream).not_to have_been_requested

    token = JWT.encode({site_scope_id: protected_scope.id, exp: 1.hour.from_now.to_i},
      Rails.application.secret_key_base, "HS256")
    get "/api/titiler/tiles/3/5/3", params: params, headers: {"Site-Scope-Token" => token}
    expect(response).to have_http_status(:ok)
    expect(response.body.b).to eq(png)
    expect(upstream).to have_been_requested.once
  end

  path "/api/titiler/info" do
    get "Get COG metadata from TiTiler" do
      tags "TiTiler"
      consumes "application/json"
      produces "application/json"
      parameter name: :titilerUrl, in: :query, type: :string, description: "TiTiler base URL", required: true
      parameter name: :cogUrl, in: :query, type: :string, description: "COG file URL", required: true

      response "400", "Missing required parameters" do
        let(:titilerUrl) { nil }
        let(:cogUrl) { nil }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to include("Missing required parameters")
        end
      end

      response "400", "Invalid TiTiler URL" do
        let(:titilerUrl) { invalid_titiler_url }
        let(:cogUrl) { cog_url }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to eq("Invalid titilerUrl")
        end
      end

      context "with valid TiTiler URL" do
        before do
          stub_request(:get, %r{#{valid_titiler_url}/info.*})
            .to_return(
              status: 200,
              body: {
                bounds: [-180, -90, 180, 90],
                dtype: "uint8",
                width: 1024,
                height: 1024
              }.to_json,
              headers: {"Content-Type" => "application/json"}
            )
        end

        response "200", "Successfully retrieves COG info", generate_swagger_example: true do
          let(:titilerUrl) { valid_titiler_url }
          let(:cogUrl) { cog_url }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to have_key("bounds")
          end
        end
      end

      context "with staging TiTiler URL" do
        before do
          stub_request(:get, %r{#{staging_titiler_url}/info.*})
            .to_return(
              status: 200,
              body: {bounds: [0, 0, 10, 10]}.to_json,
              headers: {"Content-Type" => "application/json"}
            )
        end

        response "200", "Successfully retrieves COG info from staging" do
          let(:titilerUrl) { staging_titiler_url }
          let(:cogUrl) { cog_url }

          run_test!
        end
      end

      context "with s3:// COG URL" do
        let(:s3_cog_url) { "s3://resilienceatlas/cogs/total_annual_rainfall.tif" }

        before do
          stub_request(:get, %r{#{valid_titiler_url}/info.*})
            .to_return(
              status: 200,
              body: {bounds: [-180, -90, 180, 90]}.to_json,
              headers: {"Content-Type" => "application/json"}
            )
        end

        response "200", "Successfully retrieves COG info for s3:// URL" do
          let(:titilerUrl) { valid_titiler_url }
          let(:cogUrl) { s3_cog_url }

          run_test! do |response|
            expect(JSON.parse(response.body)).to have_key("bounds")
          end
        end

        response "400", "Rejects s3:// URL from disallowed bucket" do
          let(:titilerUrl) { valid_titiler_url }
          let(:cogUrl) { "s3://malicious-bucket/evil.tif" }

          run_test! do |response|
            expect(JSON.parse(response.body)["error"]).to eq("Invalid cogUrl")
          end
        end
      end
    end
  end

  path "/api/titiler/statistics" do
    post "Compute statistics for a COG within a geometry" do
      tags "TiTiler"
      consumes "application/json"
      produces "application/json"
      parameter name: :titilerUrl, in: :query, type: :string, description: "TiTiler base URL", required: true
      parameter name: :cogUrl, in: :query, type: :string, description: "COG file URL", required: true
      parameter name: :bidx, in: :query, type: :integer, description: "Band index (1-based)", required: false
      parameter name: :categorical, in: :query, type: :boolean, description: "Treat as categorical data", required: false
      parameter name: :histogram_bins, in: :query, type: :integer, description: "Number of histogram bins", required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          type: {type: :string, example: "Feature"},
          geometry: {
            type: :object,
            properties: {
              type: {type: :string, example: "Polygon"},
              coordinates: {type: :array}
            }
          }
        }
      }, required: true

      let(:geojson_body) do
        {
          type: "Feature",
          geometry: {
            type: "Polygon",
            coordinates: [[[-10, -10], [10, -10], [10, 10], [-10, 10], [-10, -10]]]
          }
        }.to_json
      end

      response "400", "Missing required parameters" do
        let(:titilerUrl) { nil }
        let(:cogUrl) { nil }
        let(:body) { geojson_body }

        before do
          allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(StringIO.new(geojson_body))
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to include("Missing required parameters")
        end
      end

      response "400", "Invalid TiTiler URL" do
        let(:titilerUrl) { invalid_titiler_url }
        let(:cogUrl) { cog_url }
        let(:body) { geojson_body }

        before do
          allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(StringIO.new(geojson_body))
        end

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to eq("Invalid titilerUrl")
        end
      end

      context "with valid parameters" do
        before do
          stub_request(:post, %r{#{valid_titiler_url}/statistics.*})
            .to_return(
              status: 200,
              body: {
                type: "FeatureCollection",
                features: [{
                  type: "Feature",
                  properties: {
                    statistics: {
                      b1: {
                        min: 0,
                        max: 255,
                        mean: 127.5,
                        std: 50.0,
                        histogram: [[10, 20, 30], [0, 100, 200, 255]]
                      }
                    }
                  }
                }]
              }.to_json,
              headers: {"Content-Type" => "application/json"}
            )
        end

        response "200", "Successfully computes statistics", generate_swagger_example: true do
          let(:titilerUrl) { valid_titiler_url }
          let(:cogUrl) { cog_url }
          let(:body) { geojson_body }

          before do
            allow_any_instance_of(ActionDispatch::Request).to receive(:body).and_return(StringIO.new(geojson_body))
          end

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data["features"].first["properties"]).to have_key("statistics")
          end
        end
      end
    end
  end

  path "/api/titiler/point" do
    get "Query raster values at a point" do
      tags "TiTiler"
      consumes "application/json"
      produces "application/json"
      parameter name: :titilerUrl, in: :query, type: :string, description: "TiTiler base URL", required: true
      parameter name: :cogUrl, in: :query, type: :string, description: "COG file URL", required: true
      parameter name: :lon, in: :query, type: :number, description: "Longitude", required: true
      parameter name: :lat, in: :query, type: :number, description: "Latitude", required: true
      parameter name: :bidx, in: :query, type: :integer, description: "Band index (1-based)", required: false

      response "400", "Missing required parameters" do
        let(:titilerUrl) { valid_titiler_url }
        let(:cogUrl) { cog_url }
        let(:lon) { nil }
        let(:lat) { nil }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to include("Missing required parameters")
        end
      end

      response "400", "Invalid coordinates" do
        let(:titilerUrl) { valid_titiler_url }
        let(:cogUrl) { cog_url }
        let(:lon) { 200 }  # Invalid: out of range
        let(:lat) { 45 }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to eq("Invalid coordinates")
        end
      end

      response "400", "Invalid TiTiler URL" do
        let(:titilerUrl) { invalid_titiler_url }
        let(:cogUrl) { cog_url }
        let(:lon) { -73.9857 }
        let(:lat) { 40.7484 }

        run_test! do |response|
          expect(JSON.parse(response.body)["error"]).to eq("Invalid titilerUrl")
        end
      end

      context "with valid parameters" do
        before do
          stub_request(:get, %r{#{valid_titiler_url}/point/-73\.9857/40\.7484.*})
            .to_return(
              status: 200,
              body: {
                coordinates: [-73.9857, 40.7484],
                values: [127, 255, 0],
                band_names: ["b1", "b2", "b3"]
              }.to_json,
              headers: {"Content-Type" => "application/json"}
            )
        end

        response "200", "Successfully queries point values", generate_swagger_example: true do
          let(:titilerUrl) { valid_titiler_url }
          let(:cogUrl) { cog_url }
          let(:lon) { -73.9857 }
          let(:lat) { 40.7484 }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to have_key("values")
            expect(data["values"]).to be_an(Array)
          end
        end
      end
    end
  end
end
