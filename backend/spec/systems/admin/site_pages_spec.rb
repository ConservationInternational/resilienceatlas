require "system_helper"

RSpec.describe "Admin: Site Pages", type: :system do
  include ActionText::SystemTestHelper

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

  describe "#show" do
    let!(:site_page) { create :site_page }

    before do
      visit admin_site_pages_path
      find("a[href='/admin/site_pages/#{site_page.id}']", text: "View").click
    end

    it "shows site_page detail" do
      expect(page).to have_text(site_page.title)
      expect(page).to have_text(site_page.body.to_plain_text)
      expect(page).to have_text(site_page.priority)
      expect(page).to have_text(site_page.slug)
    end
  end

  describe "#create" do
    let!(:site_scope) { create :site_scope }
    let(:new_site_page) { SitePage.last }

    before do
      visit admin_site_pages_path
      click_on "New Site Page"
    end

    it "allows to create new site_page" do
      fill_in "site_page[title]", with: "New title"
      select site_scope.name, from: "site_page[site_scope_id]"
      fill_in_rich_text_area with: "New body"
      fill_in "site_page[priority]", with: "100"
      fill_in "site_page[slug]", with: "new-site-page"

      click_on "Create Site page"

      expect(page).to have_current_path(admin_site_page_path(new_site_page))
      expect(page).to have_text("Site page was successfully created.")
      expect(page).to have_text("New title")
      expect(page).to have_text("New body")
      expect(page).to have_text("100")
      expect(page).to have_text("new-site-page")
    end
  end

  describe "#update" do
    let!(:site_page) { create :site_page }

    before do
      visit admin_site_pages_path
      find("a[href='/admin/site_pages/#{site_page.id}/edit']").click
    end

    it "allows to update existing site_page" do
      fill_in "site_page[title]", with: "Update title"

      click_on "Update Site page"

      expect(page).to have_current_path(admin_site_page_path(site_page))
      expect(page).to have_text("Site page was successfully updated.")
      expect(page).to have_text("Update title")
    end
  end

  describe "#delete" do
    let!(:site_page) { create :site_page }

    before do
      visit admin_site_pages_path
    end

    it "deletes existing site_page" do
      expect(page).to have_text(site_page.title)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/site_pages/#{site_page.id}']").click
      end

      expect(page).not_to have_text(site_page.title)
    end
  end
end
