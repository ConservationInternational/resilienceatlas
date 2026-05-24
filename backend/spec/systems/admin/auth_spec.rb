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

          expect(page).to have_selector("a", text: "Dashboard", visible: false)
          expect(page).to have_selector("a", text: "Admin Users", visible: false)
          expect(page).to have_selector("a", text: "Categories", visible: false)
          expect(page).to have_selector("a", text: "Indicators", visible: false)
          expect(page).to have_selector("a", text: "Journeys", visible: false)
          expect(page).to have_selector("a", text: "Languages", visible: false)
          expect(page).to have_selector("a", text: "Layer Groups", visible: false)
          expect(page).to have_selector("a", text: "Layers", visible: false)
          expect(page).to have_selector("a", text: "Map Menu Entries", visible: false)
          expect(page).to have_selector("a", text: "Models", visible: false)
          expect(page).to have_selector("a", text: "Site Pages", visible: false)
          expect(page).to have_selector("a", text: "Site Scopes", visible: false)
          expect(page).to have_selector("a", text: "Sources", visible: false)
          expect(page).to have_selector("a", text: "User Downloads", visible: false)
          expect(page).to have_selector("a", text: "Users", visible: false)
        end
      end

      context "with staff role admin" do
        let!(:admin_user) { create :admin_user, role: :staff }

        it "sees correct items at navigation" do
          login_as admin_user

          expect(page).to have_selector("a", text: "Dashboard", visible: false)
          expect(page).not_to have_selector("a", text: "Admin Users", visible: false)
          expect(page).to have_selector("a", text: "Categories", visible: false)
          expect(page).not_to have_selector("a", text: "Indicators", visible: false)
          expect(page).not_to have_selector("a", text: "Journeys", visible: false)
          expect(page).not_to have_selector("a", text: "Languages", visible: false)
          expect(page).to have_selector("a", text: "Layer Groups", visible: false)
          expect(page).to have_selector("a", text: "Layers", visible: false)
          expect(page).not_to have_selector("a", text: "Map Menu Entries", visible: false)
          expect(page).not_to have_selector("a", text: "Models", visible: false)
          expect(page).not_to have_selector("a", text: "Site Pages", visible: false)
          expect(page).not_to have_selector("a", text: "Site Scopes", visible: false)
          expect(page).not_to have_selector("a", text: "Sources", visible: false)
          expect(page).not_to have_selector("a", text: "User Downloads", visible: false)
          expect(page).not_to have_selector("a", text: "Users", visible: false)
        end
      end
    end

    context "when wrong credentials" do
      it "shows error message" do
        fill_in "admin_user[email]", with: "admin@example.com"
        fill_in "admin_user[password]", with: "secret3"

        click_on "Login"

        expect(page).to have_text("Invalid email or password.")
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
