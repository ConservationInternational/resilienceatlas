require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

require "super_diff/rspec-rails"

# Configure Capybara for system tests - Selenium drivers disabled
require "capybara/rails"
# Note: All Selenium drivers have been disabled in favor of Cuprite

# Explicitly prevent Capybara from loading any selenium drivers
if defined?(Capybara)
  # Override selenium driver registration to prevent loading
  %i[selenium selenium_headless selenium_chrome selenium_chrome_headless].each do |driver_name|
    Capybara.register_driver(driver_name) do |app|
      raise "Selenium driver (#{driver_name}) disabled! Use :cuprite instead."
    end
  end

  # Also prevent any automatic selenium driver initialization
  Capybara.configure do |config|
    config.default_driver = :cuprite
    config.javascript_driver = :cuprite
  end
end

Dir[Rails.root.join("spec", "support", "**", "*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  puts e.to_s.strip
  exit 1
end

RSpec.configure do |config|
  config.fixture_paths = ["#{::Rails.root}/spec/fixtures"]
  config.request_snapshots_dir = "spec/fixtures/snapshots"
  config.request_snapshots_dynamic_attributes = %w[id uid layer_group_id layer_id auth_token image_data url image_url small medium original created_at updated_at record_id]
  config.request_snapshots_ignore_order = %w[data included timeline_steps]

  config.include RequestHelpers, type: :request
  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Warden::Test::Helpers

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
