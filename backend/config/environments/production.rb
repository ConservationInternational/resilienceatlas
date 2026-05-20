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

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # NGINX, varnish or squid.
  # config.action_dispatch.rack_cache = true

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

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX
  config.action_dispatch.x_sendfile_header = "X-Accel-Redirect"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # INTENTIONALLY DISABLED: TLS is terminated at the AWS Application Load Balancer (ALB) before
  # reaching Rails. Enabling force_ssl here would cause redirect loops because the ALB forwards
  # plain HTTP to the Rails container. The ALB listener enforces HTTPS at the network edge.
  # config.force_ssl = true

  # Treat all incoming requests as HTTPS (TLS terminated at ALB). Sets secure cookie flags and
  # emits https:// URLs without causing HTTP→HTTPS redirect loops. Requires Rails 7.1+.
  config.assume_ssl = true

  # config.logger = ActiveSupport::Logger.new("log/production.log")
  # :info hides per-query SQL logs that are only useful during debugging.
  # Use LOG_LEVEL=debug env var to re-enable temporarily when needed.
  config.log_level = ENV.fetch("LOG_LEVEL", "info").to_sym
  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new($stdout)
    logger.formatter = config.log_formatter
    logger.level = config.log_level
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end
  # Prepend all log lines with the following tags.
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups.
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)

  # Use a different cache store in production.
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

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Send deprecation notices to registered listeners.
  # config.active_support.deprecation = :notify

  # Do not dump schema after migrations.
  # config.active_record.dump_schema_after_migration = false

  config.action_mailer.default_url_options = {host: URI.parse(ENV.fetch("BACKEND_URL")).host}
  config.action_mailer.delivery_method = :sparkpost

  # Set default URL options for controllers (needed for Active Storage URLs)
  backend_uri = URI.parse(ENV.fetch("BACKEND_URL"))
  Rails.application.routes.default_url_options = {
    host: backend_uri.host,
    port: backend_uri.port,
    protocol: backend_uri.scheme
  }

  # Store uploaded files in S3 with instance-role credentials (private access, signed URLs).
  # Seeded static assets that must be publicly accessible should live in public/ or a CDN,
  # not through Active Storage.
  config.active_storage.service = :amazon
end
