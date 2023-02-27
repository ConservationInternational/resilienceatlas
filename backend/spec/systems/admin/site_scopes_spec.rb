require "system_helper"

RSpec.describe "Admin: Site Scopes", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:site_scopes) { create_list :site_scope, 3 }

    before { visit admin_site_scopes_path }

    it "shows all resources" do
      SiteScope.all.each do |site_scope|
        expect(page).to have_text(site_scope.name)
      end
    end
  end
end
