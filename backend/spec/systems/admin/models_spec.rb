require "system_helper"

RSpec.describe "Admin: Models", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:models) { create_list :model, 3 }

    before { visit admin_models_path }

    it "shows all resources" do
      Model.all.each do |model|
        expect(page).to have_text(model.name)
      end
    end
  end

  describe "#show" do
    let!(:model) { create :model }

    before do
      visit admin_models_path
      find("a[href='/admin/models/#{model.id}']", text: "View").click
    end

    it "shows model detail" do
      expect(page).to have_text(model.name)
      expect(page).to have_text(model.description)
      expect(page).to have_text(model.source)
      expect(page).to have_text(model.query_analysis)
      expect(page).to have_text(model.table_name)
    end
  end

  describe "#create" do
    let(:new_model) { Model.order(:created_at).last }

    before do
      visit admin_models_path
      click_on "New Model"
    end

    it "allows to create new model" do
      fill_in "model[name]", with: "New name"
      fill_in "model[description]", with: "New description"
      fill_in "model[source]", with: "New source"
      fill_in "model[query_analysis]", with: "New query analysis"
      fill_in "model[table_name]", with: "New table name"

      click_on "Create Model"

      expect(page).to have_current_path(admin_model_path(new_model))
      expect(page).to have_text("Model was successfully created.")
      expect(page).to have_text("New name")
      expect(page).to have_text("New description")
      expect(page).to have_text("New source")
      expect(page).to have_text("New query analysis")
      expect(page).to have_text("New table name")
    end

    it "shows error when validation fails" do
      fill_in "model[name]", with: ""

      click_on "Create Model"

      expect(page).to have_current_path(admin_models_path)
      expect(page).to have_text("can't be blank")
    end
  end

  describe "#update" do
    let!(:model) { create :model }

    before do
      visit admin_models_path
      find("a[href='/admin/models/#{model.id}/edit']").click
    end

    it "allows to update existing model" do
      fill_in "model[name]", with: "Update name"

      click_on "Update Model"

      expect(page).to have_current_path(admin_model_path(model))
      expect(page).to have_text("Model was successfully updated.")
      expect(page).to have_text("Update name")
    end
  end

  describe "#delete" do
    let!(:model) { create :model, name: "Custom Name" }

    before do
      visit admin_models_path
    end

    it "deletes existing model" do
      expect(page).to have_text(model.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/models/#{model.id}']").click
      end

      expect(page).not_to have_text(model.name)
    end
  end
end
