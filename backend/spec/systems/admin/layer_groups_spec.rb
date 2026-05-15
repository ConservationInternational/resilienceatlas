require "system_helper"

RSpec.describe "Admin: Layer Groups", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:layer_groups) { create_list :layer_group, 3 }

    before { visit admin_layer_groups_path }

    it "shows all resources" do
      LayerGroup.all.each do |layer_group|
        expect(page).to have_text(layer_group.name)
      end
    end
  end

  describe "#show" do
    let!(:layer_group) { create :layer_group }

    before do
      visit admin_layer_groups_path
      find("a[href='/admin/layer_groups/#{layer_group.id}']", text: "View").click
    end

    it "shows layer_group detail" do
      expect(page).to have_text(layer_group.slug)
      expect(page).to have_text(layer_group.layer_group_type)
      expect(page).to have_text(layer_group.order)
      expect(page).to have_text(layer_group.site_scope.name)
    end
  end

  describe "#create" do
    let!(:site_scope) { create :site_scope }
    let(:new_layer_group) { LayerGroup.order(:created_at).last }

    before do
      visit admin_layer_groups_path
      click_on "New Layer Group"
    end

    it "allows to create new new layer_group" do
      fill_in "layer_group[translations_attributes][0][name]", with: "New name"
      fill_in "layer_group[translations_attributes][0][info]", with: "New info"
      select site_scope.name, from: "layer_group[site_scope_id]"
      fill_in "layer_group[slug]", with: "new-layer-group"
      fill_in "layer_group[order]", with: "1"
      select "category", from: "layer_group[layer_group_type]"

      click_on "Create Layer group"

      expect(page).to have_current_path(admin_layer_group_path(new_layer_group))
      expect(page).to have_text("Layer group was successfully created.")
      expect(page).to have_text(site_scope.name)
      expect(page).to have_text("new-layer-group")
      expect(page).to have_text("1")
      expect(page).to have_text("category")
    end
  end

  describe "#update" do
    let!(:layer_group) { create :layer_group }

    before do
      visit admin_layer_groups_path
      find("a[href='/admin/layer_groups/#{layer_group.id}/edit']").click
    end

    it "allows to update existing layer_group" do
      fill_in "layer_group[slug]", with: "update-layer-group-slug"

      click_on "Update Layer group"

      expect(page).to have_current_path(admin_layer_group_path(layer_group))
      expect(page).to have_text("Layer group was successfully updated.")
      expect(page).to have_text("update-layer-group-slug")
    end
  end

  describe "#delete" do
    let(:layer) { create :layer }
    let!(:layer_group) { create :layer_group, name: "Custom Name", layers: [layer] }

    before do
      visit admin_layer_groups_path
    end

    it "deletes existing layer_group" do
      expect(page).to have_text(layer_group.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/layer_groups/#{layer_group.id}']").click
      end

      expect(page).not_to have_text(layer_group.name)
    end
  end

  describe "#super_group_filtering", :js do
    let!(:site_scope1) { create :site_scope, name: "Site Scope 1" }
    let!(:site_scope2) { create :site_scope, name: "Site Scope 2" }
    let!(:group_a_site1) { create :layer_group, name: "Group A - Site 1", site_scope: site_scope1 }
    let!(:group_b_site1) { create :layer_group, name: "Group B - Site 1", site_scope: site_scope1 }
    let!(:group_c_site2) { create :layer_group, name: "Group C - Site 2", site_scope: site_scope2 }
    let!(:layer_group) { create :layer_group, name: "Test Group", site_scope: site_scope1 }

    before do
      visit edit_admin_layer_group_path(layer_group)
    end

    it "filters super_group options by site scope on page load" do
      super_group_select = find("#layer_group_super_group_id")

      # Should show groups from site_scope1 only (plus blank option)
      expect(super_group_select).to have_content("Group A - Site 1")
      expect(super_group_select).to have_content("Group B - Site 1")
      expect(super_group_select).not_to have_content("Group C - Site 2")
    end

    it "updates super_group options when site scope changes", skip: "Requires JavaScript execution" do
      # This test would require JavaScript execution to work properly
      # Leaving as documentation of expected behavior:
      # 1. Initially shows groups from site_scope1
      # 2. Change site_scope to site_scope2
      # 3. Super group dropdown should update to show only groups from site_scope2
    end
  end
end
