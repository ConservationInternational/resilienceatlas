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
end
