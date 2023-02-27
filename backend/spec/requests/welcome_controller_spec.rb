require "rails_helper"

RSpec.describe WelcomeController, type: :request do
  describe "GET #index" do
    before { get root_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end
end
