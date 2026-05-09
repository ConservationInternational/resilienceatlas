require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ConservationInternational
  class Application < Rails::Application
    config.load_defaults 7.2

    # Parse BACKEND_URL and handle both full URLs and service names
    backend_url_env = ENV.fetch("BACKEND_URL", "http://localhost:3000")
    begin
      backend_url = URI.parse(backend_url_env)
      # If parsing a service name without protocol, it becomes the path, not host
      Rails.application.routes.default_url_options = if backend_url.host.nil? && backend_url.path.present?
        # This is likely a service name, set defaults for container environment
        {
          host: backend_url_env,
          port: 3000,
          protocol: "http"
        }
      else
        # This is a proper URL
        {
          host: backend_url.host,
          port: backend_url.port,
          protocol: backend_url.scheme
        }
      end
    rescue URI::InvalidURIError
      # Fallback for invalid URIs - treat as service name
      Rails.application.routes.default_url_options = {
        host: backend_url_env,
        port: 3000,
        protocol: "http"
      }
    end

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = "Europe/Madrid"

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.autoload_lib(ignore: %w[assets tasks])
    config.i18n.available_locales = [:en, :es, :"pt-BR", :fr, :ru, :"zh-CN"]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]

    # Setup scaffold
    config.generators do |g|
      g.template_engine :slim
      g.assets false
      g.helper false
      g.test_framework :rspec
    end

    # Heroku Asset Pippeline
    config.assets.initialize_on_precompile = false

    # Compress text-based HTTP responses (JSON, HTML, CSS, JS, XML) with gzip.
    # Placed just after ActionDispatch::Static so static files served from /public
    # bypass compression (already on disk, CDN handles delivery). The :if condition
    # prevents wasteful re-compression of already-compressed binary content (images,
    # archives, video) that may be returned by Rails controllers (e.g. send_file).
    config.middleware.insert_after ActionDispatch::Static, Rack::Deflater,
      if: lambda { |_env, _status, headers, _body|
        headers["Content-Type"].to_s.match?(%r{\A(text/|application/(json|javascript|xml|xhtml\+xml|atom\+xml|rss\+xml))})
      }
  end
end
