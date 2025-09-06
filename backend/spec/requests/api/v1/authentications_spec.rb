require "swagger_helper"

RSpec.describe "API V1 Authentications", type: :request do
  let(:user) { create :user }

  path "/users/authenticate" do
    post "Authenticate user (obtain token)" do
      tags "User"
      consumes "application/json"
      produces "application/json"
      parameter name: :user_params, in: :body, schema: {
        type: :object,
        properties: {
          email: {type: :string},
          password: {type: :string}
        },
        required: ["email", "password"]
      }

      response "200", :success do
        let(:user_params) do
          {
            email: user.email,
            password: user.password
          }
        end

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/authenticate_user")
        end
      end

      response "401", "Unauthorized", generate_swagger_example: true do
        let(:user_params) do
          {
            email: user.email,
            password: "WRONG_PASSWORD"
          }
        end

        run_test!
      end
    end
  end
end
