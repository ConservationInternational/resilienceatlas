# frozen_string_literal: true

class Api::AdminController < ActionController::Base
  # include DeviseTokenAuth::Concerns::SetUserByToken

  # before_action :authenticate_api_admin_user!

  before_action :authenticate_api_token

  def authenticate_api_token
    authenticate_with_token || handle_bad_authentication
  end

  def authenticate_with_token
    authenticate_with_http_token do |auth_token, _options|
      auth_token == ENV["RESILIENCE_API_KEY"]
    end
  end

  def handle_bad_authentication
    render json: {success: false, message: "Invalid API Credentials"}, status: :unauthorized
  end
end
