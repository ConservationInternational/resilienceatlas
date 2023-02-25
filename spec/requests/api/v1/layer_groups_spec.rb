require "swagger_helper"

RSpec.describe "API V1 Layer groups", type: :request do
  path "/api/layer-groups" do
    get "Get list of layer groups" do
      tags "LayerGroup"
      consumes "application/json"
      produces "application/json"
      parameter name: :site_scope, in: :query, type: :string, description: "Site scope to list layers for", required: false

      let(:default_site_scope) { create :site_scope, id: 1, name: "CIGRP" }
      let(:extra_site_scope) { create :site_scope, id: 2 }
      let!(:layer_groups) { create_list :layer_group, 3, site_scope: default_site_scope }
      let!(:layer_group_with_different_site_scope) { create :layer_group, site_scope: extra_site_scope }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/layer_groups")
        end

        context "when filtered by site scope" do
          let(:site_scope) { extra_site_scope.subdomain }

          it "returns only layer groups for appropriate site scope" do
            expect(response_json["data"].pluck("id")).to eq([layer_group_with_different_site_scope.id.to_s])
          end
        end
      end
    end
  end
end
