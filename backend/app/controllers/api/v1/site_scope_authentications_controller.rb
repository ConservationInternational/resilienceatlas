module Api
  module V1
    class SiteScopeAuthenticationsController < ApiController
      skip_before_action :authenticate_request, raise: false

      def authenticate
        site_scope = find_site_scope
        
        unless site_scope
          render json: { 
            errors: [{ status: "404", title: "Site scope not found" }] 
          }, status: :not_found
          return
        end

        unless site_scope.requires_authentication?
          render json: { 
            message: "Site scope does not require authentication",
            authenticated: true 
          }, status: :ok
          return
        end

        username = params[:username]
        password = params[:password]

        if site_scope.authenticate_with_password(username, password)
          # Generate a simple token for this session
          token = generate_site_scope_token(site_scope.id)
          
          render json: { 
            message: "Authentication successful", 
            token: token,
            authenticated: true 
          }, status: :ok
        else
          render json: { 
            errors: [{ status: "401", title: "Invalid credentials" }] 
          }, status: :unauthorized
        end
      end

      def check_access
        site_scope = find_site_scope
        
        unless site_scope
          render json: { 
            errors: [{ status: "404", title: "Site scope not found" }] 
          }, status: :not_found
          return
        end

        unless site_scope.requires_authentication?
          render json: { 
            requires_authentication: false,
            authenticated: true 
          }, status: :ok
          return
        end

        token = request.headers['Site-Scope-Token'] || params[:token]
        
        if token && verify_site_scope_token(token, site_scope.id)
          render json: { 
            requires_authentication: true,
            authenticated: true 
          }, status: :ok
        else
          render json: { 
            requires_authentication: true,
            authenticated: false 
          }, status: :ok
        end
      end

      private

      def find_site_scope
        subdomain = params[:site_scope] || params[:subdomain]
        return nil unless subdomain.present?
        
        SiteScope.find_by(subdomain: subdomain)
      end

      def generate_site_scope_token(site_scope_id)
        payload = {
          site_scope_id: site_scope_id,
          exp: 24.hours.from_now.to_i # Token expires in 24 hours
        }
        
        JWT.encode(payload, Rails.application.secret_key_base, 'HS256')
      end

      def verify_site_scope_token(token, site_scope_id)
        decoded = JWT.decode(token, Rails.application.secret_key_base, true, { algorithm: 'HS256' })
        payload = decoded.first
        
        payload['site_scope_id'] == site_scope_id && payload['exp'] > Time.current.to_i
      rescue JWT::DecodeError, JWT::ExpiredSignature
        false
      end
    end
  end
end
