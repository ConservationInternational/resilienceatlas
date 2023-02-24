require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'support/factory_bot'

RspecApiDocumentation.configure do |config|
  config.format    = [:json, :combined_text, :html]
  config.curl_host = 'http://resilienceatlas.org/api'
  config.api_name  = "Resilience Atlas API"
end

def json
  JSON.parse(response_body)['data']
end

def json_main
  JSON.parse(response_body)
end

module ValidUserRequestHelper
  include Warden::Test::Helpers
  def sign_in_as_a_user
    @user ||= FactoryBot.create(:user)
    login_as @user
  end
end

include ValidUserRequestHelper
