require "swagger_helper"

RSpec.describe "API V1 Indicators", type: :request do
  path "/api/indicators" do
    get "Get list of indicators" do
      tags "Indicator"
      consumes "application/json"
      produces "application/json"
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:indicators) { create_list :indicator, 3 }
      let!(:scope) do
        create(:site_scope, id: 1).tap do
          SiteScope.connection.reset_pk_sequence!(SiteScope.table_name)
        end
      end
      let!(:model) { create(:model, site_scopes: [scope], indicators: indicators) }
      let!(:foreign_model) { create(:model, site_scopes: [create(:site_scope)], indicators: [indicators.first]) }
      let!(:foreign_indicator) { create(:indicator, models: [foreign_model]) }

      response "200", :success do
        run_test!

        it "returns only this scope's indicators and models", generate_swagger_example: true do
          expect(response_json["data"].pluck("id")).to match_array(indicators.map { |indicator| indicator.id.to_s })
          included_models = response_json["included"].select { |record| record["type"] == "models" }
          expect(included_models.pluck("id")).to eq([model.id.to_s])
          expect(response_json.dig("meta", "total_indicators")).to eq(3)
        end
      end
    end
  end
end
