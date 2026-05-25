class Api::HealthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :check_subdomain
  skip_before_action :get_subdomain
  skip_before_action :set_locale

  # GET /health - Liveness check for Docker/Swarm health checks.
  # Always returns 200 if the web server is responding.
  # Reports dependency status in the body for monitoring but does NOT
  # fail the HTTP status, so Swarm won't restart-loop the backend when
  # the database is temporarily unavailable.
  def show
    status = build_status
    render json: status, status: 200
  end

  # GET /health/ready - Readiness check for ALB/load balancer routing.
  # Returns 503 if critical dependencies (database) are unavailable.
  def ready
    status = build_status
    http_status = status[:database].include?("unhealthy") ? 503 : 200
    render json: status, status: http_status
  end

  private

  def build_status
    database_status = begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      "healthy"
    rescue => e
      Rails.logger.error "[HealthCheck] database unhealthy: #{e.message}"
      "unhealthy"
    end

    redis_status = if defined?(Redis) && Rails.application.config.respond_to?(:cache_store)
      begin
        Rails.cache.read("health_check")
        "healthy"
      rescue => e
        Rails.logger.error "[HealthCheck] redis unhealthy: #{e.message}"
        "unhealthy"
      end
    else
      "not configured"
    end

    {
      status: "ok",
      timestamp: Time.current.iso8601,
      database: database_status,
      redis: redis_status,
      environment: Rails.env
    }
  end
end
