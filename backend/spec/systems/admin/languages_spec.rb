require "system_helper"

RSpec.describe "Admin: Languages", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    before { visit admin_languages_path }

    it "shows all resources" do
      I18n.available_locales.each do |language|
        expect(page).to have_text(language)
      end
    end
  end

  describe "#update" do
    before do
      visit admin_languages_path
      click_on I18n.available_locales.join(" ")
    end

    it "allows to update available locales" do
      fill_in "languages", with: "en test"

      click_on "Save changes"

      expect(page).to have_current_path(admin_languages_path)
      expect(page).to have_text("Changes saved")
      expect(page).to have_text("en test")
    end
  end
end
