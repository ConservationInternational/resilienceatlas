require 'rails_helper'

RSpec.describe Users::UserAccountController, type: :request do
  context 'with signed user' do
    let(:user) { create(:user) }

    before { sign_in user }

    describe "GET #edit" do
      before { get edit_user_path(user) }

      it "returns success" do
        expect(response).to have_http_status(:success)
      end
    end
  end
end
