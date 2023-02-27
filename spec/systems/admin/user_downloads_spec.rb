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
end
