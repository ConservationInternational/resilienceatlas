require "system_helper"

RSpec.describe "Admin: Admin Users", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:admin_users) { create_list :admin_user, 3 }

    before { visit admin_admin_users_path }

    it "shows all resources" do
      AdminUser.all.each do |admin_user|
        expect(page).to have_text(admin_user.email)
      end
    end
  end
end
