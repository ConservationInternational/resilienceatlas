require "swagger_helper"

RSpec.describe "API V1 Models", type: :request do
  path "/api/models" do
    get "Get list of models" do
      tags "Model"
      consumes "application/json"
      produces "application/json"
      parameter name: :site_scope, in: :query, type: :integer, description: "Site scope to list layers for", required: false

      let(:default_site_scope) { create :site_scope, id: 1, name: 'CIGRP' }
      let(:extra_site_scope) { create :site_scope, id: 2 }
      let!(:models) { create_list :model, 3, site_scopes: [default_site_scope] }
      let!(:model_with_different_site_scope) { create :model, site_scopes: [extra_site_scope] }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/models")
        end

        context "when filtered by site scope" do
          let(:site_scope) { extra_site_scope.id }

          it "returns only models for appropriate site scope" do
            expect(response_json["data"].pluck("id")).to eq([model_with_different_site_scope.id.to_s])
          end
        end
      end
    end
  end
end
