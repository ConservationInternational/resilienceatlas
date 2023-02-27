require "swagger_helper"

RSpec.describe "API V1 Oembeds", type: :request do
  path "/services/oembed" do
    get "Get appropriate iframe" do
      tags "Oembed"
      consumes "application/json"
      produces "application/json"
      parameter name: :url, in: :query, type: :string, required: false
      parameter name: :format, in: :query, type: :string, required: false
      parameter name: :maxwidth, in: :query, type: :integer, required: false
      parameter name: :maxheight, in: :query, type: :integer, required: false

      response "200", :success do
        let(:url) { "http://resilienceatlas.org/map?test=test" }

        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_oembed_json")
        end

        context "when url is base 64 encoded" do
          let(:url) { Base64.encode64 "http://resilienceatlas.org/map?test=test" }

          it "matches snapshot" do
            expect(response.body).to match_snapshot("api/v1/get_oembed_json")
          end
        end
      end

      response "400", "Domain does not include map path" do
        let(:url) { "http://resilienceatlas.org/wrong_path?test=test" }

        run_test!
      end

      response "403", "Domain is not permitted" do
        let(:url) { "http://unpermitted.org/map?test=test" }

        run_test!
      end

      response "404", "Domain information is missing" do
        let(:url) { "" }

        run_test!
      end

      response "422", "Domain is not url or base64 string" do
        let(:url) { "WRONG_DATA" }

        run_test!
      end
    end
  end
end
