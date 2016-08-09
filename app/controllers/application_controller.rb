class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :null_session, only: Proc.new { |c| c.request.format.json? }

  before_action :check_subdomain, :get_subdomain
  after_action  :set_csrf_cookie, :store_location
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

  def after_sign_in_path_for(resource)
    session[:previous_url] || root_path
  end

  private

  def allow_site_iframe
    if request.domain == "vitalsigns.org" || request.domain == "localhost"
      url = 'vitalsigns.org'
      req_url = request.url
      if req_url.include?('rwanda')
        url = 'rwanda.vitalsigns.org'
      elsif req_url.include?('uganda')
        url = 'uganda.vitalsigns.org'
      elsif req_url.include?('tanzania')
        url = 'tanzania.vitalsigns.org'
      elsif req_url.include?('ghana')
        url = 'ghana.vitalsigns.org'
      end
      response.headers['X-Frame-Options'] = "ALLOW-FROM #{url}"
    end
  end

  protected

  def json_request?
    request.format.json?
  end
end
