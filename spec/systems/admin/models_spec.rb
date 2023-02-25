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
end
