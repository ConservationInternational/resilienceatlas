# frozen_string_literal: true

# Staging environment configuration
# Based on production settings with some adjustments for testing

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.serve_static_files = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :terser
  config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true


  # Use Redis when available (requires REDIS_URL env var), otherwise memory store.
  config.cache_store = if ENV["REDIS_URL"].present?
    [:redis_cache_store, {
      url: ENV["REDIS_URL"],
      expires_in: 1.hour,
      error_handler: ->(method:, returning:, exception:) {
        Rails.logger.warn("Redis cache #{method} failed: #{exception.message}")
      }
    }]
  else
    [:memory_store, {size: 64.megabytes}]
  end

  # Use a higher log level in staging to reduce noise but still capture issues
  config.log_level = :info

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    logger.level = config.log_level
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  config.action_mailer.default_url_options = {host: URI.parse(ENV.fetch("BACKEND_URL")).host}
  config.action_mailer.delivery_method = :sparkpost

  # Set default URL options for controllers (needed for Active Storage URLs)
  backend_uri = URI.parse(ENV.fetch("BACKEND_URL"))
  Rails.application.routes.default_url_options = {
    host: backend_uri.host,
    port: backend_uri.port,
    protocol: backend_uri.scheme
  }

  # Store uploaded files on the local file system (see config/storage.yml for options).
  # Using local_public to serve files directly from public/storage without Rails controller,
  # which is required for the seeded image assets to work correctly.
  config.active_storage.service = :local_public
end
