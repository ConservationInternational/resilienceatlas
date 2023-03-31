require "swagger_helper"

RSpec.describe "API V1 Categories", type: :request do
  path "/api/categories" do
    get "Get list of categories" do
      tags "Category"
      consumes "application/json"
      produces "application/json"
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:categories) { create_list :category, 3 }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/categories")
        end
      end
    end
  end
end
