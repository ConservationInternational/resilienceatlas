require "swagger_helper"

RSpec.describe "API V1 Journeys", type: :request do
  path "/api/journeys" do
    get "Get list of journeys" do
      tags "Journey"
      consumes "application/json"
      produces "application/json"
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let!(:journeys) { create_list :journey, 3, published: true }
      let(:unpublished_journey) { create :journey, published: false }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/journeys")
        end

        it "does not contain unpublished journey" do
          expect(response_json["data"].pluck("id")).not_to include(unpublished_journey.id)
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
      parameter name: :locale, in: :query, type: :string, description: "Used language. Default: en", required: false

      let(:journey_step_landing) { create :journey_step, step_type: :landing, position: 1 }
      let(:journey_step_conclusion) { create :journey_step, step_type: :conclusion, position: 2 }
      let(:journey_step_chapter) { create :journey_step, step_type: :chapter, position: 3, chapter_number: 3 }
      let(:journey_step_embed) { create :journey_step, step_type: :embed, position: 4 }
      let!(:journey) do
        create :journey, journey_steps: [journey_step_landing, journey_step_conclusion, journey_step_chapter, journey_step_embed]
      end
      let(:id) { journey.id }

      it_behaves_like "with not found error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_journey", ignore_order: %w[data])
        end

        context "with locale" do
          before do
            I18n.with_locale(:en) { journey.update! title: "Title EN" }
            I18n.with_locale(:es) { journey.update! title: "Title ES" }
          end

          run_test!

          context "with en value" do
            let(:locale) { "en" }

            it "contains translated value" do
              expect(response_json["data"]["attributes"]["title"]).to eq("Title EN")
            end
          end

          context "with es value" do
            let(:locale) { "es" }

            it "contains translated value" do
              expect(response_json["data"]["attributes"]["title"]).to eq("Title ES")
            end
          end

          context "with fr value" do
            it "fallback to default language" do
              expect(response_json["data"]["attributes"]["title"]).to eq("Title EN")
            end
          end
        end
      end
    end
  end
end
