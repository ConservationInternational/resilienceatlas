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
end
