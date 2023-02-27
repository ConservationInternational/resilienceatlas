require "system_helper"

RSpec.describe "Admin: Auth", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  describe "Login" do
    before { visit admin_root_path }

    it "authenticate user successfully" do
      expect(page).to have_text("You need to sign in or sign up before continuing.")

      login_as admin_user

      expect(page).to have_text("Logout")
    end

    context "when wrong credentials" do
      it "shows error message" do
        fill_in "admin_user[email]", with: "admin@example.com"
        fill_in "admin_user[password]", with: "secret3"

        click_on "Login"

        expect(page).to have_text("Invalid Email or password.")
      end
    end
  end

  describe "Log out" do
    before { login_as admin_user }

    it "works well" do
      expect(page).to have_text("Logout")

      click_on "Logout"

      expect(page).to have_text("You need to sign in or sign up before continuing.")
      expect(page).to have_current_path(new_admin_user_session_path)
    end
  end
end
