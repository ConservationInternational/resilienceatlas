require "system_helper"

RSpec.describe "Admin: Sources", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:sources) { create_list :source, 3 }

    before { visit admin_sources_path }

    it "shows all resources" do
      Source.all.each do |source|
        expect(page).to have_text(source.id)
      end
    end
  end

  describe "#show" do
    let!(:source) { create :source }

    before do
      visit admin_sources_path
      find("a[href='/admin/sources/#{source.id}']", text: "View").click
    end

    it "shows source detail" do
      expect(page).to have_text(source.source_type)
      expect(page).to have_text(source.reference)
      expect(page).to have_text(source.reference_short)
      expect(page).to have_text(source.url)
      expect(page).to have_text(source.contact_name)
      expect(page).to have_text(source.contact_email)
      expect(page).to have_text(source.license)
      expect(page).to have_text(source.version)
      expect(page).to have_text(source.spatial_resolution_units)
      expect(page).to have_text(source.license_url)
    end
  end

  describe "#create" do
    let(:new_source) { Source.last }

    before do
      visit admin_sources_path
      click_on "New Source"
    end

    it "allows to create new source" do
      fill_in "source[source_type]", with: "New source type"
      fill_in "source[reference]", with: "New reference"
      fill_in "source[reference_short]", with: "New reference short"
      fill_in "source[url]", with: "http://url.com"
      fill_in "source[contact_name]", with: "New contact name"
      fill_in "source[contact_email]", with: "email@email.com"
      fill_in "source[license]", with: "MIT"
      fill_in "source[version]", with: "v0.1"
      select "Kilometers", from: "source[spatial_resolution_units]"
      fill_in "source[license_url]", with: "http://license.com"

      click_on "Create Source"

      expect(page).to have_current_path(admin_source_path(new_source))
      expect(page).to have_text("Source was successfully created.")
      expect(page).to have_text("New source type")
      expect(page).to have_text("New reference")
      expect(page).to have_text("New reference short")
      expect(page).to have_text("http://url.com")
      expect(page).to have_text("New contact name")
      expect(page).to have_text("email@email.com")
      expect(page).to have_text("MIT")
      expect(page).to have_text("v0.1")
      expect(page).to have_text("Kilometers")
      expect(page).to have_text("http://license.com")
    end
  end

  describe "#update" do
    let!(:source) { create :source }

    before do
      visit admin_sources_path
      find("a[href='/admin/sources/#{source.id}/edit']").click
    end

    it "allows to update existing source" do
      fill_in "source[source_type]", with: "Update source type"

      click_on "Update Source"

      expect(page).to have_current_path(admin_source_path(source))
      expect(page).to have_text("Source was successfully updated.")
      expect(page).to have_text("Update source type")
    end
  end

  describe "#delete" do
    let!(:source) { create :source, source_type: "Custom source type" }

    before do
      visit admin_sources_path
    end

    it "deletes existing source" do
      expect(page).to have_text(source.source_type)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/sources/#{source.id}']").click
      end

      expect(page).not_to have_text(source.source_type)
    end
  end
end
