require "system_helper"

RSpec.describe "Admin: Admin Users", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:admin_users) { create_list :admin_user, 3 }

    before { visit admin_admin_users_path }

    it "shows all resources" do
      AdminUser.all.each do |admin_user|
        expect(page).to have_text(admin_user.email)
      end
    end
  end

  describe "#show" do
    before do
      visit admin_admin_users_path
      find("a[href='/admin/admin_users/#{admin_user.id}']", text: "View").click
    end

    it "shows admin user detail" do
      expect(page).to have_text(admin_user.email)
      expect(page).to have_text(admin_user.role)
    end
  end

  describe "#create" do
    let(:new_admin_user) { AdminUser.order(:created_at).last }

    before do
      visit admin_admin_users_path
      click_on "New Admin User"
    end

    it "allows to create new admin user" do
      fill_in "admin_user[email]", with: "test@test.test"
      fill_in "admin_user[password]", with: "SuperSecret6"
      fill_in "admin_user[password_confirmation]", with: "SuperSecret6"
      select "Manager", from: "admin_user[role]"

      click_on "Create Admin user"

      expect(page).to have_current_path(admin_admin_user_path(new_admin_user))
      expect(page).to have_text("Admin user was successfully created.")
      expect(page).to have_text("test@test.test")
      expect(page).to have_text("manager")
    end

    it "shows error when validation fails" do
      fill_in "admin_user[email]", with: "WRONG"

      click_on "Create Admin user"

      expect(page).to have_current_path(admin_admin_users_path)
      expect(page).to have_text("is invalid")
    end
  end

  describe "#update" do
    let!(:extra_admin_user) { create :admin_user }

    before do
      visit admin_admin_users_path
      find("a[href='/admin/admin_users/#{extra_admin_user.id}/edit']").click
    end

    it "allows to update existing admin user" do
      fill_in "admin_user[email]", with: "new_email@test.test"

      click_on "Update Admin user"

      expect(page).to have_current_path(admin_admin_user_path(extra_admin_user))
      expect(page).to have_text("Admin user was successfully updated.")
      expect(page).to have_text("new_email@test.test")
    end
  end

  describe "#delete" do
    let!(:extra_admin_user) { create :admin_user }

    before do
      visit admin_admin_users_path
    end

    it "deletes existing admin user" do
      expect(page).to have_text(extra_admin_user.email)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/admin_users/#{extra_admin_user.id}']").click
      end

      expect(page).not_to have_text(extra_admin_user.email)
    end
  end
end
