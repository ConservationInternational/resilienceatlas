require "system_helper"

RSpec.describe "Admin: Site Pages", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:site_pages) { create_list :site_page, 3 }

    before { visit admin_site_pages_path }

    it "shows all resources" do
      SitePage.all.each do |site_page|
        expect(page).to have_text(site_page.title)
      end
    end
  end
end
