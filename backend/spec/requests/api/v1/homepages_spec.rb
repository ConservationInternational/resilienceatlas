require "swagger_helper"

RSpec.describe "API V1 Homepages", type: :request do
  path "/api/homepage" do
    get "Get homepage for appropriate site scope" do
      tags "Homepage"
      consumes "application/json"
      produces "application/json"
      parameter name: :site_scope, in: :query, type: :string, description: "Site scope subdomain. Fallbacks to default site scope.", required: false
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:homepage_journey) { create :homepage_journey }
      let!(:homepage) { create :homepage, show_journeys: true, homepage_journey: homepage_journey }
      let!(:homepage_section) { create :homepage_section, homepage: homepage }
      let(:site_scope) { homepage.site_scope.subdomain }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_homepage")
        end
      end

      response "404", "Site scope does not have homepage", generate_swagger_example: true do
        let(:site_scope) { create(:site_scope).subdomain }

        run_test!
      end
    end
  end
end
