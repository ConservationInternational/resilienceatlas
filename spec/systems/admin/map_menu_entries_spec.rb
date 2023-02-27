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
end
