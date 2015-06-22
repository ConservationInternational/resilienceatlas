require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Neptis
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Europe/Madrid'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Including more folders to Asset pippeline
    config.assets.paths << Rails.root.join('vendor', 'assets', 'bower_components')

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Setup scaffold
    config.generators do |g|
      g.template_engine :slim
      g.assets false
    end

    # Heroku Asset Pippeline
    config.assets.initialize_on_precompile = true
    # config.requirejs.loader = :almond
    config.requirejs.logical_asset_filter += [/\.handlebars$/]
    config.requirejs.logical_asset_filter += [/\.pgsql$/]
    config.requirejs.logical_asset_filter += [/\.json$/]
    config.requirejs.logical_asset_filter += [/\.cartocss$/]
  end
end
