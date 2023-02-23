require "swagger_helper"

RSpec.describe "API V1 Sites", type: :request do
  path "/api/sites" do
    get "Get list of all site scopes" do
      tags "SiteScope"
      consumes "application/json"
      produces "application/json"

      let!(:default_site_scope) { create :site_scope, id: 1, name: 'CIGRP' }
      let!(:extra_site_scope) { create :site_scope, id: 2 }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/site_scopes")
        end
      end
    end
  end

  path "/api/site" do
    get "Get appropriate site scope" do
      tags "SiteScope"
      consumes "application/json"
      produces "application/json"
      parameter name: :site_scope, in: :query, type: :string, description: "Site scope subdomain", required: false

      let(:default_site_scope) { create :site_scope, id: 1, name: 'CIGRP' }
      let(:site_scope) { default_site_scope.subdomain }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_site_scope")
        end
      end
    end
  end
end
