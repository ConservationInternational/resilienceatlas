Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  # config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  # config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = false

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.action_mailer.default_url_options = {host: "localhost", port: 3000}
  config.action_mailer.delivery_method = :letter_opener

  # Set default URL options for controllers (needed for Active Storage URLs)
  # Use environment variable for backend URL, defaulting to localhost for development
  backend_uri = URI.parse(ENV.fetch("BACKEND_URL", "http://localhost:3001"))
  Rails.application.routes.default_url_options = {
    host: backend_uri.host,
    port: backend_uri.port,
    protocol: backend_uri.scheme
  }

  # Set Action Controller URL options for Active Storage
  config.action_controller.default_url_options = {
    host: backend_uri.host,
    port: backend_uri.port,
    protocol: backend_uri.scheme
  }

  # Ensure Active Storage URLs use the same host/port
  config.after_initialize do
    Rails.application.routes.default_url_options = {
      host: backend_uri.host,
      port: backend_uri.port,
      protocol: backend_uri.scheme
    }
  end

  config.log_level = :debug

  # Allow Docker container hostnames for development
  # This is needed when the frontend container calls the backend via Docker network
  config.hosts << "backend"
  config.hosts << "backend:3000"
  config.hosts << "localhost"
  config.hosts << "localhost:3000"
  config.hosts << "localhost:3001"
  config.hosts << "127.0.0.1"

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    logger.level = config.log_level
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
  config.active_storage.service = :local
  config.factory_bot.definition_file_paths = ["spec/factories"]
end
