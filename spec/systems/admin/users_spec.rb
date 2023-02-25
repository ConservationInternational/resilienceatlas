require "system_helper"

RSpec.describe "Admin: Users", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:users) { create_list :user, 3 }

    before { visit admin_users_path }

    it "shows all resources" do
      User.all.each do |user|
        expect(page).to have_text(user.email)
      end
    end
  end
end
