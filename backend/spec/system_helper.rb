require "capybara/cuprite"
require "rails_helper"

# Set up proper temp directory for Ruby (not world-writable)
ENV['TMPDIR'] = '/tmp/appuser-tmp' if File.directory?('/tmp/appuser-tmp')

# Increase default wait times for more stable tests
Capybara.default_max_wait_time = 30  # Reduced from 60 for faster tests
Capybara.default_normalize_ws = true
Capybara.enable_aria_label = true
Capybara.automatic_reload = true

Capybara.register_driver(:cuprite) do |app|
  options = {
    window_size: [1920, 1080],
    # Ferrum-specific options for browser startup
    browser_options: {
      "remote-debugging-port": "9222",
      "remote-debugging-address": "0.0.0.0",
      # Additional flags for better modal support
      "disable-web-security": nil,
      "disable-features": "VizDisplayCompositor",
      "enable-automation": nil,
      "disable-background-timer-throttling": nil,
      "disable-renderer-backgrounding": nil,
      "disable-backgrounding-occluded-windows": nil
    },
    # Critical timeout settings - optimized for speed vs stability
    timeout: 60,            # Reduced from 120 for faster tests
    process_timeout: 120,   # Reduced from 180
    # Use our Chrome wrapper with absolute path
    browser_path: "/app/chrome_wrapper.sh",
    headless: ENV["HEADLESS"] != "false",
    # Reduce slowmo for faster tests
    slowmo: ENV["CI"] ? 0.1 : 0.05,  # Reduced for speed
    inspector: false,
    # Additional options to help with container stability
    ignore_https_errors: true,
    ignore_default_browser_options: false,
    # Set receive buffer
    ws_max_receive_size: 1024 * 1024 * 5, # Reduced from 10MB to 5MB
    # Temp directory configuration for Ferrum
    tmpdir: "/tmp/appuser-tmp",
    # Additional stability options
    xvfb: ENV["DISPLAY"] == ":99",
    # Reduce retry interval for faster recovery
    retry_interval: 0.5,
    # Better modal handling
    pending_connection_errors: false,
    # Optimize for speed
    ws_url_timeout: 120  # Reduced from 180
  }
  
  Capybara::Cuprite::Driver.new(app, **options)
end

# Configure Capybara to use :cuprite driver by default
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite

# Ensure we're not using any selenium drivers
Capybara.drivers.delete(:selenium)
Capybara.drivers.delete(:selenium_headless)
Capybara.drivers.delete(:selenium_chrome)
Capybara.drivers.delete(:selenium_chrome_headless)

puts "[SYSTEM_TEST] Configured drivers: #{Capybara.drivers.keys}"
puts "[SYSTEM_TEST] Default driver: #{Capybara.default_driver}"
puts "[SYSTEM_TEST] JavaScript driver: #{Capybara.javascript_driver}"

RSpec.configure do |config|
  config.include PageHelpers, type: :system

  config.around(:each, type: :system) do |ex|
    was_host = Rails.application.default_url_options[:host]
    Rails.application.default_url_options[:host] = Capybara.server_host
    ex.run
    Rails.application.default_url_options[:host] = was_host
  end

  # Use shared browser session for better performance
  config.before(:suite) do
    if RSpec.configuration.files_to_run.any? { |f| f.include?('systems/') || f.include?('system/') }
      puts "[SYSTEM_TEST] Starting shared browser session for test suite"
      
      # Pre-warm the browser session to avoid startup delays
      begin
        Capybara.current_session.visit('about:blank')
        puts "[SYSTEM_TEST] Shared browser session ready"
      rescue => e
        puts "[SYSTEM_TEST] Warning: Could not pre-warm browser session: #{e.message}"
      end
    end
  end

  config.before(:each, type: :system) do
    # Ensure we're using the right driver
    Capybara.current_driver = :cuprite
    puts "[SYSTEM_TEST] Using driver: #{Capybara.current_driver}"
    
    # Verify driver exists
    unless Capybara.drivers.key?(:cuprite)
      raise "Cuprite driver not registered! Available drivers: #{Capybara.drivers.keys}"
    end
    
    # Just reset the session, don't restart the browser
    begin
      Capybara.current_session.reset!
    rescue => e
      puts "[SYSTEM_TEST] Warning: Could not reset session: #{e.message}"
      # If reset fails, try to restart the session
      Capybara.current_session.quit
      Capybara.current_driver = :cuprite
    end
  end
  
  # Clean up after each test but keep browser alive
  config.after(:each, type: :system) do
    begin
      # Clear cookies and localStorage but keep browser running
      if Capybara.current_session.driver.respond_to?(:browser)
        browser = Capybara.current_session.driver.browser
        if browser.respond_to?(:evaluate)
          browser.evaluate('localStorage.clear()') rescue nil
          browser.evaluate('sessionStorage.clear()') rescue nil
        end
      end
      
      # Reset Capybara session state
      Capybara.current_session.reset!
    rescue => e
      puts "[SYSTEM_TEST] Warning: Could not clean up session: #{e.message}"
    end
  end

  # Clean up browser at the end of the test suite
  config.after(:suite) do
    begin
      if Capybara.current_session
        puts "[SYSTEM_TEST] Closing shared browser session"
        Capybara.current_session.quit
      end
    rescue => e
      puts "[SYSTEM_TEST] Warning: Could not close browser session: #{e.message}"
    end
  end
end
