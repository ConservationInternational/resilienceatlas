require "system_helper"

RSpec.describe "Admin: Layers", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:layers) { create_list :layer, 3 }

    before { visit admin_layers_path }

    it "shows all resources" do
      Layer.all.each do |layer|
        expect(page).to have_text(layer.name)
      end
    end
  end

  describe "#show" do
    let!(:layer) { create :layer }

    before do
      visit admin_layers_path
      find("a[href='/admin/layers/#{layer.id}']", text: "View").click
    end

    it "shows layer detail" do
      expect(page).to have_text(layer.name)
      expect(page).to have_text(layer.slug)
      expect(page).to have_text(layer.layer_type)
    end
  end

  describe "#create" do
    let(:new_layer) { Layer.last }

    before do
      visit admin_layers_path
      click_on "New Layer"
    end

    it "allows to create new layer" do
      fill_in "layer[translations_attributes][0][name]", with: "New name"
      fill_in "layer[slug]", with: "new-layer"
      select "layer", from: "layer[layer_type]"

      click_on "Create Layer"

      expect(page).to have_current_path(admin_layer_path(new_layer))
      expect(page).to have_text("Layer was successfully created.")
      expect(page).to have_text("New name")
      expect(page).to have_text("new-layer")
      expect(page).to have_text("layer")
    end
  end

  describe "#update" do
    let!(:layer) { create :layer }

    before do
      visit admin_layers_path
      find("a[href='/admin/layers/#{layer.id}/edit']").click
    end

    it "allows to update existing layer" do
      fill_in "layer[translations_attributes][0][name]", with: "Update name"

      click_on "Update Layer"

      expect(page).to have_current_path(admin_layer_path(layer))
      expect(page).to have_text("Layer was successfully updated.")
      expect(page).to have_text("Update name")
    end
  end

  describe "#delete" do
    let!(:layer) { create :layer, name: "Custom name" }

    before do
      visit admin_layers_path
    end

    it "deletes existing layer" do
      expect(page).to have_text(layer.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/layers/#{layer.id}']").click
      end

      expect(page).not_to have_text(layer.name)
    end
  end
end
