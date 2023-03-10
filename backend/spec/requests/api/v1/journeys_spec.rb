require "swagger_helper"

RSpec.describe "API V1 Journeys", type: :request do
  path "/api/journeys" do
    get "Get list of journeys" do
      tags "Journey"
      consumes "application/json"
      produces "application/json"

      let!(:journeys) { create_list :journey, 3 }

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

      let(:journey_step_landing) { create :journey_step, step_type: :landing }
      let(:journey_step_conclusion) { create :journey_step, step_type: :conclusion }
      let(:journey_step_chapter) { create :journey_step, step_type: :chapter }
      let(:journey_step_embed) { create :journey_step, step_type: :embed }
      let!(:journey) do
        create :journey, journey_steps: [journey_step_landing, journey_step_conclusion, journey_step_chapter, journey_step_embed]
      end
      let(:id) { journey.id }

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
