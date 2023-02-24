class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session, only: Proc.new { |c| c.request.format.json? }

  before_action :check_subdomain, :get_subdomain
  after_action  :set_csrf_cookie, :store_location
  before_action :set_locale
  after_action :allow_site_iframe

  def set_csrf_cookie
    if protect_against_forgery?
      cookies['X-CSRF-Token'] = form_authenticity_token
    end
  end

  def get_subdomain
     @subdomain = request.subdomain != '' ? request.subdomain(0).split('.')[0] : 'main'
     @site_name = SiteScope.find_by(subdomain: request.subdomain).try(:name)
   end

  def check_subdomain
    return unless request.get?
    if (!request.subdomain.downcase.match('www') &&
        !request.subdomain.downcase.match('staging-cigrp') &&
        !request.subdomain.downcase.match('staging') &&
        !request.subdomain.blank? &&
        !request.fullpath.match('/map') &&
        !request.fullpath.match('/contents') &&
        !request.fullpath.match('/users') &&
        !request.fullpath.match('/admin') &&
        !request.xhr?)
      redirect_to map_path
    end
  end

  def store_location
    return unless request.get?
    if (!request.fullpath.match('/users') &&
        !request.fullpath.match('/admin') &&
        !request.xhr?)
      session[:previous_url] = request.fullpath
    end
  end

  def set_locale
    I18n.locale = if params[:locale].present? && I18n.available_locales.map{|x| x.to_s}.include?(params[:locale])
                    params[:locale]
                  else
                    I18n.default_locale.to_s
                  end
  end

  def after_sign_in_path_for(resource)
    if resource.class == User
      session[:previous_url] || root_path
    elsif resource.class == AdminUser
      admin_root_path
    else
    end
  end

  private

  def allow_site_iframe
    if ['resilienceatlas.org', 'vitalsigns.org', 'globalresiliencepartnership.org', 'herokuapp.com'].include? request.domain
      response.headers.except! 'X-Frame-Options'
    end
  end

  protected

  def authenticate_request
    @current_user = ::AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end

  def json_request?
    request.format.json?
  end
end
