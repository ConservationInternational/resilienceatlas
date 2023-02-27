require "swagger_helper"

RSpec.describe "API V1 Journeys", type: :request do
  path "/api/journeys" do
    get "Get list of journeys" do
      tags "Journey"
      consumes "application/json"
      produces "application/json"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/journeys")
        end
      end
    end
  end

  path "/api/journeys/{id}" do
    get "Get appropriate journey" do
      tags "Journey"
      consumes "application/json"
      produces "application/json"
      parameter name: :id, in: :path, type: :integer, description: "Journey ID"

      let(:id) { 1 } # ids are hardcoded as names of json files at public folder

      it_behaves_like "with not found error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_journey")
        end
      end
    end
  end
end
