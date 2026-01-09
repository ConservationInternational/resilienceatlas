require "system_helper"

RSpec.describe "Admin: User Downloads", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:user_downloads) { create_list :user_download, 3 }

    before { visit admin_user_downloads_path }

    it "shows all resources" do
      UserDownload.all.each do |user_download|
        expect(page).to have_text(user_download.user.name)
        expect(page).to have_text(user_download.layer.name)
      end
    end
  end

  describe "#show" do
    let!(:user_download) { create :user_download }

    before do
      visit admin_user_downloads_path
      find("a[href='/admin/user_downloads/#{user_download.id}']", text: "View").click
    end

    it "shows user_download detail" do
      expect(page).to have_text(user_download.subdomain)
      expect(page).to have_text(user_download.user.name)
      expect(page).to have_text(user_download.layer.name)
    end
  end
end
