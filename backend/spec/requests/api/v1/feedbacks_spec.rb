require "swagger_helper"

RSpec.describe "API V1 Feedbacks", type: :request do
  path "/api/feedbacks" do
    post "Save new feedback" do
      tags "Photo"
      consumes "application/json"
      produces "application/json"
      parameter name: :feedback_params, in: :body, schema: {
        type: :object,
        properties: {
          feedback: {
            type: :object,
            properties: {
              language: {type: :string},
              feedback_fields_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    feedback_field_type: {type: :string},
                    question: {type: :string, nullable: true},
                    answer: {type: :object, nullable: true},
                    children_attributes: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          feedback_field_type: {type: :string},
                          question: {type: :string, nullable: true},
                          answer: {type: :object, nullable: true}
                        },
                        required: ["feedback_field_type"]
                      }
                    }
                  },
                  required: ["feedback_field_type"]
                }
              }
            },
            required: ["language"]
          }
        },
        required: ["feedback"]
      }

      response "200", :success do
        let(:feedback_params) do
          {
            feedback: {
              language: "en",
              feedback_fields_attributes: [{
                feedback_field_type: "single_choice",
                question: "What is your favorite color?",
                answer: {value: "Red", slug: "red"}
              }, {
                feedback_field_type: "multiple_choice",
                question: "What are your the least favorite color?",
                answer: {value: ["Green", "Yellow"], slug: ["green", "yellow"]}
              }, {
                feedback_field_type: "boolean_choice",
                question: "Do you like blue?",
                answer: {value: true, slug: "true"}
              }, {
                feedback_field_type: "free_answer",
                question: "Why you don't like yellow?",
                answer: {value: "I don't know", slug: "i-don-t-know"}
              }, {
                feedback_field_type: "rating",
                question: "Color preferences",
                answer: nil,
                children_attributes: [{
                  feedback_field_type: "single_choice",
                  question: "Red",
                  answer: {value: 3, slug: "3"}
                }, {
                  feedback_field_type: "single_choice",
                  question: "Blue",
                  answer: {value: 5, slug: "5"}
                }]
              }]
            }
          }
        end

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/create_feedback")
        end
      end

      response "422", :unprocessable_entity, generate_swagger_example: true do
        let(:feedback_params) { {feedback: {language: nil}} }

        run_test!
      end
    end
  end
end
