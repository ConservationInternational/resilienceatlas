require 'rails_helper'

RSpec.describe Users::UserAccountController, type: :controller do
  context 'For current user' do
    let(:user) { create(:user) }

    before { sign_in user }

    it "Should have a current_user" do
      expect(subject.current_user).to_not eq(nil)
    end

    it "Should get update profile page" do
      get :edit
      expect(response).to have_http_status(:success)
    end
  end
end
