require "system_helper"

RSpec.describe "Admin: Sources", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:sources) { create_list :source, 3 }

    before { visit admin_sources_path }

    it "shows all resources" do
      Source.all.each do |source|
        expect(page).to have_text(source.id)
      end
    end
  end
end
