# frozen_string_literal: true

# Rollbar configuration for error tracking and monitoring
# https://docs.rollbar.com/docs/ruby

# Rate limiter to prevent Rollbar spam during outages (e.g., database down)
# Tracks errors by fingerprint and limits how many of each type are sent
module RollbarRateLimiter
  class << self
    RATE_LIMIT_CONFIG = {
      window_seconds: 60,          # 1 minute window
      max_per_window: 5,           # Max 5 of same error per minute
      cleanup_interval_seconds: 300 # Cleanup every 5 minutes
    }.freeze

    def should_limit?(error_or_message)
      @error_counts ||= {}
      @last_cleanup ||= Time.now.to_i

      maybe_cleanup
      key = generate_key(error_or_message)
      now = Time.now.to_i
      entry = @error_counts[key]

      if entry.nil?
        # First occurrence
        @error_counts[key] = { count: 1, first_seen: now, last_seen: now, suppressed: 0 }
        return false
      end

      # Check if within rate limit window
      if now - entry[:first_seen] < RATE_LIMIT_CONFIG[:window_seconds]
        if entry[:count] >= RATE_LIMIT_CONFIG[:max_per_window]
          # Rate limited
          entry[:suppressed] += 1
          entry[:last_seen] = now
          return true
        end
        entry[:count] += 1
        entry[:last_seen] = now
        return false
      end

      # Window expired, reset
      @error_counts[key] = { count: 1, first_seen: now, last_seen: now, suppressed: 0 }
      false
    end

    def suppressed_count(error_or_message)
      key = generate_key(error_or_message)
      @error_counts&.dig(key, :suppressed) || 0
    end

    def stats
      total_suppressed = @error_counts&.values&.sum { |e| e[:suppressed] } || 0
      {
        tracked_errors: @error_counts&.size || 0,
        total_suppressed: total_suppressed
      }
    end

    private

    def generate_key(error_or_message)
      case error_or_message
      when Exception
        # Use class name + message + first backtrace line for fingerprinting
        backtrace_line = error_or_message.backtrace&.first || ""
        "exc:#{error_or_message.class}:#{error_or_message.message}:#{backtrace_line}"
      when String
        "str:#{error_or_message}"
      else
        "obj:#{error_or_message.class}:#{error_or_message.to_s[0..100]}"
      end
    end

    def maybe_cleanup
      now = Time.now.to_i
      return unless now - @last_cleanup >= RATE_LIMIT_CONFIG[:cleanup_interval_seconds]

      @last_cleanup = now
      cutoff = now - (RATE_LIMIT_CONFIG[:window_seconds] * 2)

      @error_counts.delete_if do |_key, entry|
        entry[:last_seen] < cutoff
      end
    end
  end
end

# Custom Rollbar notifier wrapper with rate limiting
module RollbarWithRateLimiting
  LEVELS = %i[debug info warning error critical].freeze

  LEVELS.each do |level|
    define_method(:"#{level}_with_rate_limit") do |message_or_exception, extra = {}|
      if RollbarRateLimiter.should_limit?(message_or_exception)
        Rails.logger.debug { "Rollbar: Rate limited #{level} - #{message_or_exception.class}" }
        return nil
      end

      suppressed = RollbarRateLimiter.suppressed_count(message_or_exception)
      extra_with_suppressed = extra.merge(
        suppressed > 0 ? { previously_suppressed: suppressed } : {}
      )

      Rollbar.public_send(level, message_or_exception, extra_with_suppressed)
    end
  end

  def self.stats
    RollbarRateLimiter.stats
  end
end

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

  # Rate limiting hook - prevent spam during outages (e.g., database down)
  # This checks all errors before they're sent to Rollbar
  config.before_process = proc { |options|
    exception = options[:exception]
    message = options[:message]
    error_source = exception || message

    if error_source && RollbarRateLimiter.should_limit?(error_source)
      Rails.logger.debug { "Rollbar: Rate limited - #{error_source.class}" } if defined?(Rails)
      throw :ignore # This tells Rollbar to skip this error
    end

    # Add suppressed count to payload if there were previously suppressed errors
    if error_source
      suppressed = RollbarRateLimiter.suppressed_count(error_source)
      if suppressed > 0
        options[:extra] ||= {}
        options[:extra][:previously_suppressed] = suppressed
      end
    end
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
