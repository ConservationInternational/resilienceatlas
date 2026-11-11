# frozen_string_literal: true

class Api::Admin::ApiController < ActionController::Base
  # This controller uses HTTP Bearer token auth, not cookie sessions.
  # CSRF protection is irrelevant here and would block all non-browser clients
  # (e.g. the Bedrock Lambda agent calling PATCH /api/admin/layers/:id).
  skip_before_action :verify_authenticity_token

  before_action :authenticate_api_token
  before_action :authenticate_actor

  rescue_from CanCan::AccessDenied do
    render json: {success: false, message: "Not authorized"}, status: :forbidden
  end
  rescue_from ActiveRecord::RecordNotFound, with: :render_record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  def authenticate_api_token
    authenticate_with_token || handle_bad_authentication
  end

  def authenticate_with_token
    authenticate_with_http_token do |auth_token, _options|
      configured = ENV["RESILIENCE_API_KEY"]
      configured.present? && ActiveSupport::SecurityUtils.secure_compare(auth_token, configured)
    end
  end

  def handle_bad_authentication
    render json: {success: false, message: "Invalid API Credentials"}, status: :unauthorized
  end

  private

  def authenticate_actor
    @api_admin_user = AdminUser.find_by(id: request.headers["X-Admin-User-Id"].presence)
    return if @api_admin_user

    render json: {success: false, message: "An admin API actor is required"}, status: :unauthorized
  end

  def current_ability
    @current_ability ||= Ability.new(@api_admin_user)
  end

  def authorize!(action, resource)
    current_ability.authorize!(action, resource)
  end

  def require_superadmin!
    raise CanCan::AccessDenied unless @api_admin_user.superadmin?
  end

  def authorized_scope!(id)
    scope = SiteScope.find(id)
    raise CanCan::AccessDenied unless @api_admin_user.superadmin? || @api_admin_user.allowed_site_scope_ids.include?(scope.id)

    scope
  end

  def render_record_not_found(exception)
    render json: {success: false, message: exception.message}, status: :not_found
  end

  def render_record_invalid(exception)
    render json: {success: false, message: "Errors", error: exception.message}, status: :unprocessable_entity
  end
end
