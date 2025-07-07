require "capybara/cuprite"
require "rails_helper"

Capybara.default_max_wait_time = 10
Capybara.default_normalize_ws = true

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1200, 800],
    browser_options: {
      "no-sandbox": nil,
      "disable-gpu": nil,
      "disable-dev-shm-usage": nil,
      "disable-setuid-sandbox": nil,
      "disable-background-timer-throttling": nil,
      "disable-backgrounding-occluded-windows": nil,
      "disable-renderer-backgrounding": nil,
      "disable-features": "TranslateUI,VizDisplayCompositor",
      "remote-debugging-port": "9222",
      "remote-debugging-address": "0.0.0.0"
    },
    timeout: 120,
    # Increase Chrome startup wait time (required for stable CI builds)
    process_timeout: 120,
    inspector: false,
    headless: ENV["HEADLESS"] != "false"
  )
end

# Configure Capybara to use :cuprite driver by default
Capybara.default_driver = Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  config.include PageHelpers, type: :system

  config.around(:each, type: :system) do |ex|
    was_host = Rails.application.default_url_options[:host]
    Rails.application.default_url_options[:host] = Capybara.server_host
    ex.run
    Rails.application.default_url_options[:host] = was_host
  end

  config.prepend_before(:each, type: :system) do
    driven_by Capybara.javascript_driver
  end
end
