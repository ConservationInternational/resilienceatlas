class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session, only: Proc.new { |c| c.request.format.json? }
  before_action :show_token
  after_filter :set_csrf_cookie
  def show_token
    Rails.logger.info verified_request?
    Rails.logger.info "**************************#{request.subdomain}"
  end

  def set_csrf_cookie
    if protect_against_forgery?
      cookies['X-CSRF-Token'] = form_authenticity_token
    end
  end

  protected

  def json_request?
    request.format.json?
  end
end
