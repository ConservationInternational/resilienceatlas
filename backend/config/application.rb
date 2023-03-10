require File.expand_path("../boot", __FILE__)

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ConservationInternational
  class Application < Rails::Application
    config.load_defaults 7.0

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
    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")
    config.i18n.available_locales = [:en, :it, :de, :es, :"pt-BR", :fr]
    config.i18n.default_locale = :en

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

    config.active_storage.variant_processor = :mini_magick
  end
end
