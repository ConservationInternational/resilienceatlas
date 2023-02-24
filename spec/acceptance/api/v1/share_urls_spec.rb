require 'acceptance_helper'

resource 'ShareUrl' do
  header "Accept", "application/json; application/vnd.api+json"
  header "Content-Type", "application/vnd.api+json"
  header 'Host', 'http://resilienceatlas.org'
  header 'X-CSRF-Token', 'a_valid_CSRF_token'

  let!(:layer) do
    FactoryBot.create(:share_url, body: "body test", uid: '12345')
  end

  get "/api/share/:uid" do
    parameter :uid, "An unique url identifier"
    let(:uid) { '12345' }

    example_request "Get a share URL by UID" do
      expect(status).to eq(200)
      results = JSON.parse(response_body)['data']['attributes']
      expect(results['body']).to be == 'body test'
    end
  end

  post "/api/share/?body=:body" do
    parameter :body, "A Json object as text "
    let(:body) { 'body test' }

    example_request "Create a share URL" do
      expect(status).to eq(200)
      results = JSON.parse(response_body)
      expect(results['uid']).to be_kind_of(String)
    end
  end
end
