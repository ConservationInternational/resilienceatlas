require "swagger_helper"

RSpec.describe "API V1 Indicators", type: :request do
  path "/api/indicators" do
    get "Get list of indicators" do
      tags "Indicator"
      consumes "application/json"
      produces "application/json"
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:indicators) { create_list :indicator, 3 }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/indicators")
        end
      end
    end
  end
end
