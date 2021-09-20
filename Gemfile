source 'https://rubygems.org'

ruby '2.7.2'

gem 'rails', '6.0.3.4'

gem 'jquery-rails'
gem 'jquery-ui-rails', '~> 6.0.1'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'slim-rails'
gem 'autoprefixer-rails'
gem 'handlebars_assets'
gem 'd3-rails', '>= 3.5.6'
gem 'dotenv-rails'
gem 'webpacker', '~> 5.0'

gem 'pg'
gem 'devise'
gem 'jwt'
gem 'simple_command'
gem 'activeadmin'
gem 'active_model_serializers', '0.10.11'

gem 'addressable'

gem 'rack-cors'

# Omniauth
gem 'omniauth'
gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'omniauth-linkedin'
gem 'omniauth-google-oauth2'

# Utilities
gem 'raddocs'
gem 'seed_dump'
gem 'active_admin_theme'
gem 'ckeditor', '4.3'
gem 'sendgrid'
gem 'rubyzip'
gem 'prawn'
gem 'prawn-table'
gem 'normalize-rails'

# Translations
gem 'globalize'
gem 'activeadmin-globalize', git: 'https://github.com/GeoffAbtion/activeadmin-globalize', branch: 'main'

# Ordering and Tree structure for menus
gem 'active_admin-sortable_tree'
gem 'ancestry'
gem 'acts_as_list'
# gem 'activeadmin-sortable'

# Ransack for Active Admin
gem 'ransack', '2.4.0'

group :production, :staging do
  gem 'puma'
end

group :development, :test do
  gem 'spring'
  gem 'teaspoon'
  gem 'teaspoon-mocha'
  gem 'byebug'
  gem 'hirb'
  gem 'awesome_print'
  gem 'faker'
  gem 'spring-commands-rspec'
  gem 'rspec_api_documentation'
  gem 'json_spec'
  gem 'bullet'
  gem 'web-console'
  gem 'capistrano'
  gem 'capistrano-rvm'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-npm'
  gem 'capistrano-passenger'
end

group :development do
  gem 'foreman'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'meta_request'
  gem 'annotate'
end

group :test do
  gem 'factory_girl_rails', '~> 4.0', require: false
  gem 'rspec-rails'
  gem 'email_spec'
  gem 'database_cleaner'
end

# Rails Assets is the frictionless proxy between Bundler and Bower.
source 'https://rails-assets.org' do
  # gem 'rails-assets-normalize-css'
  gem 'rails-assets-foundation-sass'
  gem 'rails-assets-foundation'
  gem 'rails-assets-underscore'
  gem 'rails-assets-backbone'
  gem 'rails-assets-moment'
  gem 'rails-assets-handlebars'
  gem 'rails-assets-slick-carousel'
  gem 'rails-assets-jquery-ui-touch-punch-valid'
end
