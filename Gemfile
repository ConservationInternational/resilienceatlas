source 'https://rubygems.org'

ruby '2.2.1'

gem 'rails', '4.2.1'

gem 'jquery-rails'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'slim-rails'
gem 'autoprefixer-rails'
gem 'handlebars_assets'

gem 'pg'
gem 'devise'
gem 'activeadmin', github: 'activeadmin'
gem 'active_model_serializers', '0.10.0.rc2'

# Utilities
gem 'rails_12factor'
gem 'raddocs'
gem 'seed_dump'

group :development, :test do
  gem 'spring'
  gem 'teaspoon'
  gem 'teaspoon-mocha'
  gem 'dotenv-rails'
  gem 'byebug'
  gem 'hirb'
  gem 'awesome_print'
  gem 'faker'
  gem 'spring-commands-rspec'
  gem 'rspec_api_documentation'
  gem 'json_spec'
  gem 'bullet'
  gem 'web-console', '~> 2.0'
end

group :development do
  gem 'foreman'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'meta_request'
  gem 'annotate', '~> 2.6.5'
end

group :test do
  gem 'factory_girl_rails', '~> 4.0', require: false
  gem 'rspec-rails'
  gem 'database_cleaner'
end

# Rails Assets is the frictionless proxy between Bundler and Bower.
source 'https://rails-assets.org' do
  gem 'rails-assets-normalize-css'
  gem 'rails-assets-foundation-sass'
  gem 'rails-assets-underscore'
  gem 'rails-assets-backbone'
  gem 'rails-assets-moment'
  gem 'rails-assets-handlebars'
end
