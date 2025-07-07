require "capybara/cuprite"
require "rails_helper"

# Set up proper temp directory for Ruby (not world-writable)
ENV['TMPDIR'] = '/tmp/appuser-tmp' if File.directory?('/tmp/appuser-tmp')

# Increase default wait times
Capybara.default_max_wait_time = 30
Capybara.default_normalize_ws = true

# Configure Ferrum timeouts at module level (this is critical for the websocket timeout)
if defined?(Ferrum)
  Ferrum.class_eval do
    class Browser
      def ws_url_timeout
        120 # Increased from 60 seconds to give Chrome more time to start
      end
    end
  end
end

Capybara.register_driver(:cuprite) do |app|
  # Debug logging
  puts "[CUPRITE] Registering driver with browser_path: /app/chrome_wrapper.sh"
  puts "[CUPRITE] Current environment variables:"
  puts "  DISPLAY: #{ENV['DISPLAY']}"
  puts "  HEADLESS: #{ENV['HEADLESS']}"
  puts "  HOME: #{ENV['HOME']}"
  puts "  USER: #{ENV['USER']}"
  
  # Check if our wrapper exists and is executable
  wrapper_path = "/app/chrome_wrapper.sh"
  if File.exist?(wrapper_path)
    puts "[CUPRITE] Chrome wrapper found at #{wrapper_path}"
    puts "[CUPRITE] Wrapper permissions: #{File.stat(wrapper_path).mode.to_s(8)}"
  else
    puts "[CUPRITE] ERROR: Chrome wrapper NOT found at #{wrapper_path}"
  end
  
  options = {
    window_size: [1920, 1080],
    # Ferrum-specific options for browser startup
    browser_options: {
      "remote-debugging-port": "9222",
      "remote-debugging-address": "0.0.0.0"
    },
    # Critical timeout settings
    timeout: 60,            # Cuprite command timeout (increased from 30)
    process_timeout: 120,   # Process spawn timeout (increased from 60)
    # Use our Chrome wrapper with absolute path
    browser_path: "/app/chrome_wrapper.sh",
    headless: ENV["HEADLESS"] != "false",
    # Slow down operations for more stability in containers
    slowmo: ENV["CI"] ? 0.1 : 0,
    inspector: false,
    # Additional options to help with container stability
    ignore_https_errors: true,
    ignore_default_browser_options: false,
    # Set larger receive buffer
    ws_max_receive_size: 1024 * 1024 * 10, # 10MB
    # Temp directory configuration for Ferrum
    tmpdir: "/tmp/appuser-tmp"
  }
  
  # Add ws_url_timeout if supported
  begin
    options[:ws_url_timeout] = 120  # Increased from 60 to give Chrome more time
  rescue ArgumentError
    # Older version of Cuprite/Ferrum might not support this
    puts "[CUPRITE] ws_url_timeout not supported, using alternatives"
  end
  
  puts "[CUPRITE] Driver options: #{options.inspect}"
  
  # Create the driver
  driver = Capybara::Cuprite::Driver.new(app, **options)
  
  # Add debug hooks if possible
  if driver.respond_to?(:browser) && driver.browser.respond_to?(:on)
    puts "[CUPRITE] Adding debug hooks to browser"
    
    # Hook into browser events if supported
    begin
      driver.browser.on(:stderr) do |data|
        puts "[CUPRITE] Chrome stderr: #{data}"
      end
      
      driver.browser.on(:stdout) do |data|
        puts "[CUPRITE] Chrome stdout: #{data}"
      end
    rescue => e
      puts "[CUPRITE] Could not add browser hooks: #{e.message}"
    end
  end
  
  driver
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
    
    # Try to access the driver to trigger browser startup
    begin
      session = Capybara.current_session
      if session.respond_to?(:driver) && session.driver.respond_to?(:browser)
        session.driver.browser
      end
    rescue => e
      puts "[SYSTEM_TEST] Error starting browser: #{e.class.name}: #{e.message}"
      # Only show logs on error for debugging
      if Dir.exist?("/tmp/chrome-logs")
        Dir.glob("/tmp/chrome-logs/*.log").each do |log_file|
          puts "[SYSTEM_TEST] Chrome log (#{log_file}):"
          content = File.read(log_file) rescue "could not read"
          puts content.split("\n").last(5).join("\n") # Last 5 lines only
        end
      end
      raise e
    end
  end
end
