require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ConservationInternational
  class Application < Rails::Application
    config.load_defaults 7.2

    backend_url = URI.parse ENV.fetch("BACKEND_URL", "http://localhost:3000")
    Rails.application.routes.default_url_options = {
      host: backend_url.host,
      port: backend_url.port,
      protocol: backend_url.scheme
    }

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
    config.assets.initialize_on_precompile = true

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*"
        resource "*", headers: :any, methods: [:get, :post, :options], expose: ["access-token", "expiry", "token-type", "uid", "client"]
        resource "/api/*", headers: :any, methods: [:get, :post, :options, :delete, :put], expose: ["access-token", "expiry", "token-type", "uid", "client"]
      end
    end
  end
end
