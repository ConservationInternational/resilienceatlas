require 'rails_helper'

RSpec.describe Users::UserAccountController, type: :controller do
  context 'For current user' do
    before :each do
      login_user
    end

    it "Should have a current_user" do
      expect(subject.current_user).to_not eq(nil)
    end

    it "Should get update profile page" do
      get 'edit', id: 1
      expect(response).to be_success
    end
  end
end
