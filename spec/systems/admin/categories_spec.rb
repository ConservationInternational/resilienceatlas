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
      end
    end
  end
end
