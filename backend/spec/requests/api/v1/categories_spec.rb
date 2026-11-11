require "swagger_helper"

RSpec.describe "API V1 Categories", type: :request do
  path "/api/categories" do
    get "Get list of categories" do
      tags "Category"
      consumes "application/json"
      produces "application/json"
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:categories) { create_list :category, 3 }
      let!(:scope) { create(:site_scope, id: 1) }
      let!(:model) { create(:model, site_scopes: [scope]) }
      let!(:indicators) { categories.map { |category| create(:indicator, category: category, models: [model]) } }
      let!(:foreign_model) { create(:model, site_scopes: [create(:site_scope)]) }
      let!(:foreign_indicator) { create(:indicator, models: [foreign_model]) }
      let!(:shared_category_indicator) { create(:indicator, category: categories.first, models: [foreign_model]) }

      response "200", :success do
        run_test!

        it "returns only this scope's categories and indicators", generate_swagger_example: true do
          expect(response_json["data"].pluck("id")).to match_array(categories.map { |category| category.id.to_s })
          expect(response_json["included"].pluck("id")).to match_array(indicators.map { |indicator| indicator.id.to_s })
          expect(response_json.dig("meta", "total_categories")).to eq(3)
        end
      end
    end
  end
end
