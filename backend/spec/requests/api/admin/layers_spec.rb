require "swagger_helper"

RSpec.describe "API Admin Layers", type: :request do
  let(:token) { "SECRET_API_KEY" }
  let(:actor) { create(:admin_user, role: "superadmin") }
  let("X-Admin-User-Id") { actor.id.to_s }
  before do |example|
    parameters = example.metadata.dig(:operation, :parameters)
    if parameters&.none? { |parameter| parameter[:name] == "X-Admin-User-Id" }
      parameters.push({name: "X-Admin-User-Id", in: :header, schema: {type: :string}, required: true})
    end
  end

  before { stub_const("ENV", ENV.to_hash.merge("RESILIENCE_API_KEY" => token)) }

  before { SiteScope.delete_all }

  def security_checked_response
    payload = response.parsed_body
    Array.wrap(payload.fetch("data")).each do |layer|
      expect(layer.fetch("data_policy")).to eq("public")
      expect(layer.fetch("security_provenance")).to eq("default_public")
      expect(layer.fetch("tile_cache_version")).to match(/\A[a-f0-9]{28,64}\z/)
      report = layer.fetch("tile_security")
      expect(report.keys).to contain_exactly("status", "reasons", "config_diagnostics", "source_key", "version", "public_cache_eligible")
      expect(report.fetch("config_diagnostics")).to be_an(Array)
      report.fetch("config_diagnostics").each do |diagnostic|
        expect(diagnostic.keys).to contain_exactly("code", "message")
        expect(diagnostic.values).to all(be_a(String))
      end
      expect(report.fetch("version")).to eq(layer.fetch("tile_cache_version"))
      expect(report.fetch("reasons")).to be_an(Array)
      expect(report.fetch("public_cache_eligible")).to be_in([true, false])
      layer.except!("data_policy", "security_provenance", "tile_cache_version", "tile_security")
    end
    payload.to_json
  end

  path "/api/admin/layers" do
    get "List of layers" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      security [tokenAuth: []]
      parameter name: "page", in: :query, type: :integer, description: "Page number. Default: 1", required: false
      parameter name: "per_page", in: :query, type: :integer, description: "Per page items. Default: 30", required: false

      let!(:layers) { create_list :layer, 3 }

      it_behaves_like "with unauthorized error"

      response "200", :success do
        let("Authorization") { "Bearer #{token}" }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(security_checked_response).to match_snapshot("api/admin/layers")
        end
      end
    end

    post "Create new layer" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      security [tokenAuth: []]
      parameter name: :layer_params, in: :body, schema: {
        type: :object,
        properties: {
          layer: {
            type: :object
          }
        }
      }

      let(:layer) { build :layer }
      let(:layer_params) { {} }

      it_behaves_like "with unauthorized error"

      response "200", :success do
        let("Authorization") { "Bearer #{token}" }
        let(:layer_params) { {layer: layer.attributes} }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(security_checked_response).to match_snapshot("api/admin/create_layer")
        end
      end

      response "422", "Validation errors" do
        let("Authorization") { "Bearer #{token}" }
        let(:layer_params) { {layer: {test: "test"}} }

        run_test!
      end
    end
  end

  path "/api/admin/layers/{id}" do
    patch "Update existing layer" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      security [tokenAuth: []]
      parameter name: :id, in: :path, type: :integer, description: "Layer ID"
      parameter name: :layer_params, in: :body, schema: {
        type: :object,
        properties: {
          layer: {
            type: :object
          }
        }
      }

      let!(:layer) { create :layer }
      let(:id) { layer.id }
      let(:layer_params) { {} }
      let("Authorization") { "Bearer #{token}" }

      it_behaves_like "with unauthorized error"
      it_behaves_like "with not found error"

      response "200", :success do
        let(:layer_params) do
          config = {body: {source: "https://storage.googleapis.com/resilienceatlas-public/test.tif"}}.to_json
          {layer: build(:layer, layer_provider: "cog", layer_config: config).attributes.except("updated_at", "created_at")}
        end

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(security_checked_response).to match_snapshot("api/admin/update_layer")
        end
      end

      response "422", "Invalid published source" do
        let(:layer_params) { {layer: {layer_provider: "cog", layer_config: {body: {source: "invalid"}}.to_json}} }

        run_test!
      end
    end

    get "Show detail of layer" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      security [tokenAuth: []]
      parameter name: :id, in: :path, type: :integer, description: "Layer ID"

      let!(:layer) { create :layer }
      let(:id) { layer.id }
      let("Authorization") { "Bearer #{token}" }

      it_behaves_like "with unauthorized error"
      it_behaves_like "with not found error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(security_checked_response).to match_snapshot("api/admin/get_layer")
        end
      end
    end

    delete "Delete appropriate layer" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      security [tokenAuth: []]
      parameter name: :id, in: :path, type: :integer, description: "Layer ID"

      let!(:layer) { create :layer }
      let(:id) { layer.id }
      let("Authorization") { "Bearer #{token}" }

      it_behaves_like "with unauthorized error"
      it_behaves_like "with not found error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(security_checked_response).to match_snapshot("api/admin/delete_layer")
        end
      end
    end
  end

  path "/api/admin/layers/site_scopes" do
    get "Get list of all site scopes" do
      tags "Layer"
      consumes "application/json"
      produces "application/json"
      security [tokenAuth: []]
      parameter name: :keyword, in: :query, type: :string, description: "Search by keyword", required: false

      let!(:site_scope_1) { create :site_scope, name: "AAA" }
      let!(:site_scope_2) { create :site_scope, name: "BBB" }
      let("Authorization") { "Bearer #{token}" }

      it_behaves_like "with unauthorized error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/admin/layers_site_scopes")
        end

        context "when searching by keyword" do
          let(:keyword) { site_scope_1.name }

          it "returns just correct site scopes" do
            expect(response_json["data"].pluck("id")).to eq([site_scope_1.id])
          end
        end

        context "when searching by subdomain keyword" do
          let!(:site_scope_1) { create :site_scope, name: "SBTN Thresholds", subdomain: "thresholds" }
          let!(:site_scope_2) { create :site_scope, name: "Forest Atlas", subdomain: "forest" }
          let(:keyword) { "threshold" }

          it "returns site scopes matched by subdomain" do
            expect(response_json["data"].pluck("id")).to eq([site_scope_1.id])
          end
        end
      end
    end
  end
end
