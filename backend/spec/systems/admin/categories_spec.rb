require "system_helper"

RSpec.describe "Admin: Categories", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:categories) { create_list :category, 3 }

    before { visit admin_categories_path }

    it "shows all resources" do
      Category.all.each do |category|
        expect(page).to have_text(category.name)
        expect(page).to have_text(category.slug)
        expect(page).to have_text(category.description)
      end
    end
  end

  describe "#show" do
    let!(:category) { create :category }

    before do
      visit admin_categories_path
      find("a[href='/admin/categories/#{category.id}']", text: "View").click
    end

    it "shows category detail" do
      expect(page).to have_text(category.name)
      expect(page).to have_text(category.slug)
      expect(page).to have_text(category.description)
    end
  end

  describe "#create" do
    let(:new_category) { Category.order(:created_at).last }

    before do
      visit admin_categories_path
      click_on "New Category"
    end

    it "allows to create new category" do
      fill_in "category[translations_attributes][0][name]", with: "New name"
      fill_in "category[translations_attributes][0][description]", with: "New description"
      fill_in "category[slug]", with: "new-category"

      click_on "Create Category"

      expect(page).to have_current_path(admin_category_path(new_category))
      expect(page).to have_text("Category was successfully created.")
      expect(page).to have_text("New name")
      expect(page).to have_text("new-category")
      expect(page).to have_text("New description")
    end

    it "shows error when validation fails" do
      fill_in "category[slug]", with: ""

      click_on "Create Category"

      expect(page).to have_current_path(admin_categories_path)
      expect(page).to have_text("can't be blank")
    end
  end

  describe "#update" do
    let!(:category) { create :category }

    before do
      visit admin_categories_path
      find("a[href='/admin/categories/#{category.id}/edit']").click
    end

    it "allows to update existing category" do
      fill_in "category[translations_attributes][0][name]", with: "Update name"
      fill_in "category[translations_attributes][0][description]", with: "Update description"

      click_on "Update Category"

      expect(page).to have_current_path(admin_category_path(category))
      expect(page).to have_text("Category was successfully updated.")
      expect(page).to have_text("Update name")
      expect(page).to have_text("Update description")
    end
  end

  describe "#delete" do
    let!(:category) { create :category }

    before do
      visit admin_categories_path
    end

    it "deletes existing category" do
      expect(page).to have_text(category.name)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/categories/#{category.id}']").click
      end

      expect(page).not_to have_text(category.name)
    end
  end
end
