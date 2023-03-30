require "system_helper"

RSpec.describe "Admin: Indicators", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:indicators) { create_list :indicator, 3 }

    before { visit admin_indicators_path }

    it "shows all resources" do
      Indicator.all.each do |indicator|
        expect(page).to have_text(indicator.name)
      end
    end
  end

  describe "#show" do
    let!(:indicator) { create :indicator }

    before do
      visit admin_indicators_path
      find("a[href='/admin/indicators/#{indicator.id}']", text: "View").click
    end

    it "shows indicator detail" do
      expect(page).to have_text(indicator.name)
      expect(page).to have_text(indicator.slug)
      expect(page).to have_text(indicator.position)
      expect(page).to have_text(indicator.version)
      expect(page).to have_text(indicator.column_name)
      expect(page).to have_text(indicator.operation)
    end
  end

  describe "#create" do
    let!(:category) { create :category }
    let(:new_indicator) { Indicator.order(:created_at).last }

    before do
      visit admin_indicators_path
      click_on "New Indicator"
    end

    it "allows to create new indicator" do
      fill_in "indicator[name]", with: "New name"
      fill_in "indicator[slug]", with: "new-indicator"
      fill_in "indicator[position]", with: "1"
      fill_in "indicator[version]", with: "0.2"
      fill_in "indicator[column_name]", with: "New column name"
      fill_in "indicator[operation]", with: "New operation"
      select category.name, from: "indicator[category_id]"

      click_on "Create Indicator"

      expect(page).to have_current_path(admin_indicator_path(new_indicator))
      expect(page).to have_text("Indicator was successfully created.")
      expect(page).to have_text("New name")
      expect(page).to have_text("new-indicator")
      expect(page).to have_text("1")
      expect(page).to have_text("0.2")
      expect(page).to have_text("New column name")
      expect(page).to have_text("New operation")
    end

    it "shows error when validation fails" do
      fill_in "indicator[name]", with: ""

      click_on "Create Indicator"

      expect(page).to have_current_path(admin_indicators_path)
      expect(page).to have_text("can't be blank")
    end
  end

  describe "#update" do
    let!(:indicator) { create :indicator }

    before do
      visit admin_indicators_path
      find("a[href='/admin/indicators/#{indicator.id}/edit']").click
    end

    it "allows to update existing indicator" do
      fill_in "indicator[name]", with: "Update name"

      click_on "Update Indicator"

      expect(page).to have_current_path(admin_indicator_path(indicator))
      expect(page).to have_text("Indicator was successfully updated.")
      expect(page).to have_text("Update name")
    end
  end

  describe "#delete" do
    let!(:indicator) { create :indicator, name: "Custom Name" }

    before do
      visit admin_indicators_path
    end

    it "deletes existing indicator" do
      expect(page).to have_text(indicator.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/indicators/#{indicator.id}']").click
      end

      expect(page).not_to have_text(indicator.name)
    end
  end
end
