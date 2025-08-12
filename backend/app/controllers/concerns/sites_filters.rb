module SitesFilters
  extend ActiveSupport::Concern
  included do
    before_action :set_site
    before_action :check_site_scope_authentication
  end

  def set_site
    @site_scope = SiteScope.find_by(subdomain: params[:site_scope]) ||
      SiteScope.find_by(subdomain: request.subdomain.downcase) ||
      SiteScope.find(1)
    params[:site_scope] = @site_scope.id
    params
  end

  def check_site_scope_authentication
    return unless @site_scope&.requires_authentication?

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

  def layers_params
    params.permit(:site_scope, :site_scope_token, :locale)
  end

  def verify_site_scope_token(token, site_scope_id)
    decoded = JWT.decode(token, Rails.application.secret_key_base, true, {algorithm: "HS256"})
    payload = decoded.first

    payload["site_scope_id"] == site_scope_id && payload["exp"] > Time.current.to_i
  rescue JWT::DecodeError, JWT::ExpiredSignature
    false
  end
end
