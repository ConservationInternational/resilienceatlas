require File.expand_path('../boot', __FILE__)

require "rails/all"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_text/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ConservationInternational
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Europe/Madrid'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.autoload_paths << Rails.root.join('lib')
    config.i18n.available_locales = [:en, :it, :de, :es, :'pt-BR', :fr]
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
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :options], expose: ['access-token', 'expiry', 'token-type', 'uid', 'client']
        resource '/api/*', headers: :any, methods: [:get, :post, :options, :delete, :put], expose: ['access-token', 'expiry', 'token-type', 'uid', 'client']
      end
    end
  end
end
