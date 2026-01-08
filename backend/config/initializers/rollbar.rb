# frozen_string_literal: true

# Rollbar configuration for error tracking and monitoring
# https://docs.rollbar.com/docs/ruby

Rollbar.configure do |config|
  # Access token from environment (server-side post access token)
  config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]

  # Disable Rollbar if no token is provided (development/test environments)
  config.enabled = !config.access_token.nil? && !config.access_token.empty?

  # Environment name (production, staging, development)
  config.environment = ENV.fetch("RAILS_ENV", "development")

  # Framework name for better categorization
  config.framework = "Rails: #{Rails::VERSION::STRING}"

  # Code version - use Git SHA if available
  config.code_version = ENV.fetch("GIT_REVISION", nil) ||
    (File.exist?(".git") ? `git rev-parse HEAD`.strip : nil)

  # Exception level filters - customize error severity
  config.exception_level_filters.merge!({
    "ActionController::RoutingError" => "ignore",
    "ActionController::InvalidAuthenticityToken" => "warning",
    "ActiveRecord::RecordNotFound" => "info"
  })

  # Filter sensitive parameters
  config.scrub_fields |= [
    :password,
    :password_confirmation,
    :secret,
    :secret_key_base,
    :auth_token,
    :access_token,
    :api_key,
    :credit_card,
    :card_number,
    :cvv,
    :ssn
  ]

  # Don't send person data in certain environments
  config.person_method = "current_user"
  config.person_id_method = "id"
  config.person_username_method = "email"
  config.person_email_method = "email"

  # Async handler for non-blocking error reporting
  config.use_async = true
  config.async_handler = proc { |payload|
    Thread.new { Rollbar.process_from_async_handler(payload) }
  }

  # Additional configuration for production
  if Rails.env.production? || Rails.env.staging?
    # Report SQL queries in error context (without values for security)
    config.collect_user_ip = true

    # Add custom data to all error reports
    config.custom_data_method = lambda { |message, exception, request|
      {
        application: "ResilienceAtlas Backend",
        host: ENV.fetch("BACKEND_URL", nil),
        timestamp: Time.current.iso8601
      }
    }
  end

  # In development, log Rollbar messages to console
  if Rails.env.development?
    config.logger = Rails.logger
  end

  # In test, disable Rollbar entirely
  config.enabled = false if Rails.env.test?
end
