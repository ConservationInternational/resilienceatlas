require "swagger_helper"

RSpec.describe "API Admin Layers", type: :request do
  let(:token) { "SECRET_API_KEY" }

  before { stub_const("ENV", ENV.to_hash.merge("RESILIENCE_API_KEY" => token)) }

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
          expect(response.body).to match_snapshot("api/admin/layers")
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
          expect(response.body).to match_snapshot("api/admin/create_layer")
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
        let(:layer_params) { {layer: build(:layer).attributes.except("timeline_format", "updated_at", "created_at")} }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/admin/update_layer")
        end
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
          expect(response.body).to match_snapshot("api/admin/get_layer")
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
          expect(response.body).to match_snapshot("api/admin/delete_layer")
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
      end
    end
  end
end
