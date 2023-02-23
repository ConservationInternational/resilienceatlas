require "swagger_helper"

RSpec.describe "API V1 ShareUrl", type: :request do
  path "/api/share/{uid}" do
    get "Get detail of shared url" do
      tags "ShareUrl"
      consumes "application/json"
      produces "application/json"
      parameter name: :uid, in: :path, type: :string, description: "An unique url identifier"

      let(:share_url) { create :share_url, body: "body test", uid: '12345' }
      let(:uid) { share_url.uid }

      it_behaves_like "with not found error"

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/get_share_url")
        end
      end
    end
  end

  path "/api/share" do
    post "Create new shared url" do
      tags "ShareUrl"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :query, type: :string, description: "Body of shared url"

      let(:body) { 'body test' }

      response "200", :success do
        run_test!

        it "matches snapshot", generate_swagger_example: true do
          expect(response.body).to match_snapshot("api/v1/create_share_url")
        end
      end
    end
  end
end
