require "swagger_helper"

RSpec.describe "API V1 Registration", type: :request do
  path "/api/photos" do
    post "Save new image" do
      tags "Photo"
      consumes "multipart/form-data"
      produces "application/json"
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

      response "201", :success do
        let("photo[image]") { fixture_file_upload("picture.jpg") }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/create_photo")
        end
      end
    end
  end
end
