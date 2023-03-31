require "swagger_helper"

RSpec.describe "API V1 Registration", type: :request do
  let(:admin_user) { create :admin_user }

  path "/api/photos" do
    post "Save new image" do
      tags "Photo"
      consumes "multipart/form-data"
      produces "application/json"
      security [cookie_auth: []]
      parameter name: "photo[image]",
        in: :formData,
        description: "Binary data of image",
        required: true,
        attributes: {
          schema: {
            type: :object,
            properties: {
              file: {type: :binary}
            }
          }
        }

      let("photo[image]") { fixture_file_upload("picture.jpg") }

      response "201", :success do
        before { sign_in admin_user }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/create_photo")
        end
      end

      response "401", "Authentication failed" do
        run_test!

        it "returns correct error", generate_swagger_example: true do
          expect(response_json["error"]).to eq("You need to sign in or sign up before continuing.")
        end
      end
    end
  end
end
