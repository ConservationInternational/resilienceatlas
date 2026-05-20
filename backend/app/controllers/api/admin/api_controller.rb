# frozen_string_literal: true

class Api::Admin::ApiController < ActionController::Base
  before_action :authenticate_api_token

  rescue_from ActiveRecord::RecordNotFound, with: :render_record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  def authenticate_api_token
    authenticate_with_token || handle_bad_authentication
  end

  def authenticate_with_token
    authenticate_with_http_token do |auth_token, _options|
      ActiveSupport::SecurityUtils.secure_compare(auth_token, ENV["RESILIENCE_API_KEY"].to_s)
    end
  end

  def handle_bad_authentication
    render json: {success: false, message: "Invalid API Credentials"}, status: :unauthorized
  end

  private

  def render_record_not_found(exception)
    render json: {success: false, message: exception.message}, status: :not_found
  end

  def render_record_invalid(exception)
    render json: {success: false, message: "Errors", error: exception.message}, status: :unprocessable_entity
  end
end
