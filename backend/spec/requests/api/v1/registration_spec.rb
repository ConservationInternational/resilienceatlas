require "swagger_helper"

RSpec.describe "API V1 Registration", type: :request do
  path "/users/register" do
    post "Register new user" do
      tags "User"
      consumes "application/json"
      produces "application/json"
      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              email: {type: :string},
              password: {type: :string},
              password_confirmation: {type: :string, nullable: true},
              first_name: {type: :string, nullable: true},
              last_name: {type: :string, nullable: true},
              organization: {type: :string, nullable: true},
              organization_role: {type: :string, nullable: true}
            },
            required: ["email", "password"]
          },
          required: ["user"]
        }
      }

      response "200", :success do
        let(:user_params) do
          {
            user: {
              first_name: "Jan",
              last_name: "Kowalski",
              email: "jankowalski@example.com",
              password: "SuperSecret1234"
            }
          }
        end

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/create_user")
        end
      end

      response "422", "Validation errors" do
        let(:user_params) { {user: {email: "WRONG_EMAIL"}} }

        run_test!
      end
    end
  end
end
