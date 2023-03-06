require "system_helper"

RSpec.describe "Admin: Users", type: :system do
  let!(:admin_user) do
    create :admin_user, email: "admin@example.com", password: "SuperSecret6", password_confirmation: "SuperSecret6"
  end

  before { login_as admin_user }

  describe "#index" do
    let!(:users) { create_list :user, 3 }

    before { visit admin_users_path }

    it "shows all resources" do
      User.all.each do |user|
        expect(page).to have_text(user.email)
      end
    end
  end

  describe "#show" do
    let!(:user) { create :user }

    before do
      visit admin_users_path
      find("a[href='/admin/users/#{user.id}']", text: "View").click
    end

    it "shows user detail" do
      expect(page).to have_text(user.email)
      expect(page).to have_text(user.first_name)
      expect(page).to have_text(user.last_name)
      expect(page).to have_text(user.phone)
      expect(page).to have_text(user.organization)
      expect(page).to have_text(user.organization_role)
    end
  end

  describe "#create" do
    let(:new_user) { User.last }

    before do
      visit admin_users_path
      click_on "New User"
    end

    it "allows to create new user" do
      fill_in "user[email]", with: "test@test.test"
      fill_in "user[first_name]", with: "New first name"
      fill_in "user[last_name]", with: "New last name"
      fill_in "user[phone]", with: "123456789"
      fill_in "user[organization]", with: "New organization"
      fill_in "user[organization_role]", with: "New organization role"
      fill_in "user[password]", with: "SuperSecret6"

      click_on "Create User"

      expect(page).to have_current_path(admin_user_path(new_user))
      expect(page).to have_text("User was successfully created.")
      expect(page).to have_text("test@test.test")
      expect(page).to have_text("New first name")
      expect(page).to have_text("New last name")
      expect(page).to have_text("123456789")
      expect(page).to have_text("New organization")
      expect(page).to have_text("New organization role")
    end
  end

  describe "#update" do
    let!(:user) { create :user }

    before do
      visit admin_users_path
      find("a[href='/admin/users/#{user.id}/edit']").click
    end

    it "allows to update existing user" do
      fill_in "user[first_name]", with: "Update first name"
      fill_in "user[password]", with: "SuperSecret6"

      click_on "Update User"

      expect(page).to have_current_path(admin_user_path(user))
      expect(page).to have_text("User was successfully updated.")
      expect(page).to have_text("Update first name")
    end
  end

  describe "#delete" do
    let!(:user) { create :user }

    before do
      visit admin_users_path
    end

    it "deletes existing user" do
      expect(page).to have_text(user.email)

      accept_confirm do
        find("a[data-method='delete'][href='/admin/users/#{user.id}']").click
      end

      expect(page).not_to have_text(user.email)
    end
  end
end
