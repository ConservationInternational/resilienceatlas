require "swagger_helper"

RSpec.describe "API V1 Users", type: :request do
  let(:user) { create :user }

  path "/users/me" do
    get "Obtains information about current user" do
      tags "User"
      consumes "application/json"
      produces "application/json"
      security [bearerAuth: []]

      it_behaves_like "with unauthorized error"

      response "200", :success do
        let(:Authorization) { auth_token_for user }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_user")
        end
      end
    end

    patch "Update current user" do
      tags "User"
      consumes "application/json"
      produces "application/json"
      security [bearerAuth: []]
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

      let(:user_params) {}

      it_behaves_like "with unauthorized error"

      response "200", :success do
        let(:Authorization) { auth_token_for user }
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
          expect(response.body).to match_snapshot("api/v1/update_user")
        end
      end

      response "422", "Validation errors" do
        let(:Authorization) { auth_token_for user }
        let(:user_params) { {user: {email: "WRONG_EMAIL"}} }

        run_test!
      end
    end
  end
end

# RSpec.describe Users::UserAccountController, type: :request do
#   context "with signed user" do
#     let(:user) { create(:user) }
#
#     #before { sign_in user }
#
#     describe "GET #edit" do
#       before { get edit_user_path(user) }
#
#       it "returns success" do
#         expect(response).to have_http_status(:success)
#       end
#     end
#   end
# end
