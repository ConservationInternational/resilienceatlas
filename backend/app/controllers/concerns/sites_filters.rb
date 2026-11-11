module SitesFilters
  extend ActiveSupport::Concern

  included do
    before_action :set_site
    before_action :check_site_scope_authentication
    after_action :protect_scope_cache
  end

  def set_site
    # Reuse any SiteScope already fetched this request (e.g. by ApplicationController#get_subdomain)
    # to avoid redundant DB round-trips.
    if params[:site_scope].present?
      requested = params[:site_scope].to_s
      @site_scope = find_site_scope_by_subdomain(requested)
      @site_scope ||= SiteScope.find_by(id: requested) if requested.match?(/\A[0-9]+\z/)
    else
      @site_scope = find_site_scope_by_subdomain(request.subdomain.downcase) || SiteScope.find_by(id: 1)
    end

    unless @site_scope
      render json: {error: "Site scope not found"}, status: :not_found
      return
    end

    params[:site_scope] = @site_scope.id
    params
  end

  def check_site_scope_authentication
    return unless @site_scope&.requires_authentication?

    # Password-protected scopes must not use public HTTP caching, since cached
    # 200 responses would bypass authentication entirely.
    response.cache_control.replace(no_store: true)
    return if respond_to?(:authorized_preview?, true) && authorized_preview?

    token = request.headers["Site-Scope-Token"] || params[:site_scope_token]

    unless token && verify_site_scope_token(token, @site_scope.id)
      render json: {
        errors: [{
          status: "401",
          title: "Site scope authentication required",
          detail: "This site scope requires authentication. Please authenticate first.",
          meta: {
            requires_authentication: true,
            site_scope: @site_scope.subdomain
          }
        }]
      }, status: :unauthorized
      nil
    end
  end

  private

  def protect_scope_cache
    response.cache_control.replace(no_store: true, private: true) if @site_scope&.requires_authentication?
  end

  def layers_params
    params.permit(:site_scope, :site_scope_token, :locale)
  end

  def verify_site_scope_token(token, site_scope_id)
    decoded = JWT.decode(token, Rails.application.secret_key_base, true, {algorithm: "HS256"})
    payload = decoded.first

    payload["site_scope_id"] == site_scope_id && payload["exp"].is_a?(Numeric) && payload["exp"] > Time.current.to_i
  rescue JWT::DecodeError, JWT::ExpiredSignature
    false
  end
end
