require "system_helper"

RSpec.describe "Admin: Map Menu Entries", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:map_menu_entries) { create_list :map_menu_entry, 3 }

    before { visit admin_map_menu_entries_path }

    it "shows all resources" do
      MapMenuEntry.all.each do |map_menu_entry|
        expect(page).to have_text(map_menu_entry.label)
      end
    end
  end

  describe "#show" do
    let!(:map_menu_entry) { create :map_menu_entry }

    before do
      visit admin_map_menu_entries_path
      find("a[href='/admin/map_menu_entries/#{map_menu_entry.id}']", text: "View").click
    end

    it "shows map_menu_entry detail" do
      expect(page).to have_text(map_menu_entry.label)
      expect(page).to have_text(map_menu_entry.link)
      expect(page).to have_text(map_menu_entry.position)
    end
  end

  describe "#create" do
    let(:new_map_menu_entry) { MapMenuEntry.order(:created_at).last }

    before do
      visit admin_map_menu_entries_path
      click_on "New Map Menu Entry"
    end

    it "allows to create new map_menu_entry" do
      fill_in "map_menu_entry[translations_attributes][0][label]", with: "New label"
      fill_in "map_menu_entry[link]", with: "http://test.test"
      fill_in "map_menu_entry[position]", with: "1"

      click_on "Create Map menu entry"

      expect(page).to have_current_path(admin_map_menu_entry_path(new_map_menu_entry))
      expect(page).to have_text("Map menu entry was successfully created.")
      expect(page).to have_text("New label")
      expect(page).to have_text("http://test.test")
      expect(page).to have_text("1")
    end

    it "shows error when validation fails" do
      fill_in "map_menu_entry[position]", with: ""

      click_on "Create Map menu entry"

      expect(page).to have_current_path(admin_map_menu_entries_path)
      expect(page).to have_text("can't be blank")
    end
  end

  describe "#update" do
    let!(:map_menu_entry) { create :map_menu_entry }

    before do
      visit admin_map_menu_entries_path
      find("a[href='/admin/map_menu_entries/#{map_menu_entry.id}/edit']").click
    end

    it "allows to update existing map_menu_entry" do
      fill_in "map_menu_entry[translations_attributes][0][label]", with: "Update label"

      click_on "Update Map menu entry"

      expect(page).to have_current_path(admin_map_menu_entry_path(map_menu_entry))
      expect(page).to have_text("Map menu entry was successfully updated.")
      expect(page).to have_text("Update label")
    end
  end

  describe "#delete" do
    let!(:map_menu_entry) { create :map_menu_entry, label: "Custom Name" }

    before do
      visit admin_map_menu_entries_path
    end

    it "deletes existing map_menu_entry" do
      expect(page).to have_text(map_menu_entry.label)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/map_menu_entries/#{map_menu_entry.id}']").click
      end

      expect(page).not_to have_text(map_menu_entry.label)
    end
  end
end
