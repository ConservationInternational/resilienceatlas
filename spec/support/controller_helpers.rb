include Devise::TestHelpers

module ControllerHelpers
  def login_user
    @request.env["devise.mapping"] = Devise.mappings[:user]
    user = create(:user)
    sign_in user
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers, type: :controller
end