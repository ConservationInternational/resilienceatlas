class Api::HealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    # Check database connectivity
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      database_status = "healthy"
    rescue => e
      database_status = "unhealthy: #{e.message}"
    end

    # Check Redis connectivity if Redis is configured
    redis_status = if defined?(Redis) && Rails.application.config.respond_to?(:cache_store)
      begin
        Rails.cache.read("health_check") # This will test Redis if Redis is the cache store
        "healthy"
      rescue => e
        "unhealthy: #{e.message}"
      end
    else
      "not configured"
    end

    status = {
      status: "ok",
      timestamp: Time.current.iso8601,
      database: database_status,
      redis: redis_status,
      environment: Rails.env
    }

    # Return 503 if any critical services are unhealthy
    http_status = database_status.include?("unhealthy") ? 503 : 200

    render json: status, status: http_status
  end
end
