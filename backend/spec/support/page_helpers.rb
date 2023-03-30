module PageHelpers
  def t(...)
    I18n.t(...)
  end

  def login_as(admin_user, password: nil)
    visit admin_root_path

    fill_in "admin_user[email]", with: admin_user.email
    fill_in "admin_user[password]", with: password || admin_user.password

    click_on "Login"
  end
end
