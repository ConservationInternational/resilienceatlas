require "system_helper"

RSpec.describe "Admin: Site Scopes", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:site_scopes) { create_list :site_scope, 3 }

    before { visit admin_site_scopes_path }

    it "shows all resources" do
      SiteScope.all.each do |site_scope|
        expect(page).to have_text(site_scope.name)
        expect(page).to have_text(site_scope.linkback_text)
        expect(page).to have_text(site_scope.linkback_url)
      end
    end
  end

  describe "#show" do
    let!(:site_scope) { create :site_scope }

    before do
      visit admin_site_scopes_path
      find("a[href='/admin/site_scopes/#{site_scope.id}']", text: "View").click
    end

    it "shows site_scope detail" do
      expect(page).to have_text(site_scope.name)
      expect(page).to have_text(site_scope.color)
      expect(page).to have_text(site_scope.subdomain)
      expect(page).to have_text(site_scope.latitude)
      expect(page).to have_text(site_scope.longitude)
      expect(page).to have_text(site_scope.header_theme)
      expect(page).to have_text(site_scope.zoom_level)
      expect(page).to have_text(site_scope.linkback_text)
      expect(page).to have_text(site_scope.linkback_url)
      expect(page).to have_text(site_scope.header_color)
      expect(page).to have_text(site_scope.logo_url)
    end
  end

  describe "#create" do
    let(:new_site_scope) { SiteScope.last }

    before do
      visit admin_site_scopes_path
      click_on "New Site Scope"
    end

    it "allows to create new site_scope" do
      fill_in "site_scope[translations_attributes][0][name]", with: "New name"
      fill_in "site_scope[translations_attributes][0][linkback_text]", with: "This is link"
      fill_in "site_scope[color]", with: "#000000"
      fill_in "site_scope[subdomain]", with: "test"
      fill_in "site_scope[latitude]", with: "10.11"
      fill_in "site_scope[longitude]", with: "20.22"
      select "ci-theme", from: "site_scope[header_theme]"
      fill_in "site_scope[zoom_level]", with: "3"
      fill_in "site_scope[linkback_url]", with: "http://test.test"
      fill_in "site_scope[header_color]", with: "#100000"
      fill_in "site_scope[logo_url]", with: "http://test.test/image.pjg"

      click_on "Create Site scope"

      expect(page).to have_current_path(admin_site_scope_path(new_site_scope))
      expect(page).to have_text("Site scope was successfully created.")
      expect(page).to have_text("New name")
      expect(page).to have_text("#000000")
      expect(page).to have_text("10.11")
      expect(page).to have_text("20.22")
      expect(page).to have_text("ci-theme")
      expect(page).to have_text("3")
      expect(page).to have_text("This is link")
      expect(page).to have_text("http://test.test")
      expect(page).to have_text("#100000")
      expect(page).to have_text("http://test.test/image.pjg")
    end
  end

  describe "#update" do
    let!(:site_scope) { create :site_scope }

    before do
      visit admin_site_scopes_path
      find("a[href='/admin/site_scopes/#{site_scope.id}/edit']").click
    end

    it "allows to update existing site_scope" do
      fill_in "site_scope[translations_attributes][0][name]", with: "Update name"

      click_on "Update Site scope"

      expect(page).to have_current_path(admin_site_scope_path(site_scope))
      expect(page).to have_text("Site scope was successfully updated.")
      expect(page).to have_text("Update name")
    end
  end

  describe "#delete" do
    let!(:site_scope) { create :site_scope, name: "Custom Name" }

    before do
      visit admin_site_scopes_path
    end

    it "deletes existing site_scope" do
      expect(page).to have_text(site_scope.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/site_scopes/#{site_scope.id}']").click
      end

      expect(page).not_to have_text(site_scope.name)
    end
  end
end
