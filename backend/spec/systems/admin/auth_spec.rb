require "system_helper"

RSpec.describe "Admin: Auth", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  describe "Login" do
    before { visit admin_root_path }

    context "with correct credentials" do
      it "authenticate user successfully" do
        expect(page).to have_text("You need to sign in or sign up before continuing.")

        login_as admin_user

        expect(page).to have_text("Logout")
      end

      context "with admin role admin" do
        let!(:admin_user) { create :admin_user, role: :admin }

        it "sees correct items at navigation" do
          login_as admin_user

          expect(page).to have_text("Dashboard")
          expect(page).to have_text("Admin Users")
          expect(page).to have_text("Categories")
          expect(page).to have_text("Indicators")
          expect(page).to have_text("Languages")
          expect(page).to have_text("Layer Groups")
          expect(page).to have_text("Layers")
          expect(page).to have_text("Map Menu Entries")
          expect(page).to have_text("Models")
          expect(page).to have_text("Site Pages")
          expect(page).to have_text("Site Scopes")
          expect(page).to have_text("Sources")
          expect(page).to have_text("User Downloads")
          expect(page).to have_text("Users")
        end
      end

      context "with manager role admin" do
        let!(:admin_user) { create :admin_user, role: :manager }

        it "sees correct items at navigation" do
          login_as admin_user

          expect(page).to have_text("Dashboard")
          expect(page).not_to have_text("Admin Users")
          expect(page).to have_text("Categories")
          expect(page).not_to have_text("Indicators")
          expect(page).not_to have_text("Languages")
          expect(page).to have_text("Layer Groups")
          expect(page).to have_text("Layers")
          expect(page).to have_text("Map Menu Entries")
          expect(page).to have_text("Models")
          expect(page).to have_text("Site Pages")
          expect(page).to have_text("Site Scopes")
          expect(page).to have_text("Sources")
          expect(page).not_to have_text("User Downloads")
          expect(page).to have_text("Users")
        end
      end

      context "with staff role admin" do
        let!(:admin_user) { create :admin_user, role: :staff }

        it "sees correct items at navigation" do
          login_as admin_user

          expect(page).to have_text("Dashboard")
          expect(page).not_to have_text("Admin Users")
          expect(page).to have_text("Categories")
          expect(page).not_to have_text("Indicators")
          expect(page).not_to have_text("Languages")
          expect(page).to have_text("Layer Groups")
          expect(page).to have_text("Layers")
          expect(page).not_to have_text("Map Menu Entries")
          expect(page).not_to have_text("Models")
          expect(page).not_to have_text("Site Pages")
          expect(page).not_to have_text("Site Scopes")
          expect(page).not_to have_text("Sources")
          expect(page).not_to have_text("User Downloads")
          expect(page).not_to have_text("Users")
        end
      end
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
