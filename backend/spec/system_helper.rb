require "capybara/cuprite"
require "rails_helper"

# Set up proper temp directory for Ruby (not world-writable)
ENV['TMPDIR'] = '/tmp/appuser-tmp' if File.directory?('/tmp/appuser-tmp')

# Increase default wait times for more stable tests
Capybara.default_max_wait_time = 60  # Increased from 30
Capybara.default_normalize_ws = true
Capybara.enable_aria_label = true
Capybara.automatic_reload = true

# Configure Ferrum timeouts at module level (this is critical for the websocket timeout)
if defined?(Ferrum)
  Ferrum.class_eval do
    class Browser
      def ws_url_timeout
        180 # Increased from 60 seconds to give Chrome more time to start
      end
      
      # Override command timeout for better stability
      def command_timeout
        120
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
      "remote-debugging-address": "0.0.0.0",
      # Additional flags for better modal support
      "disable-web-security": nil,
      "disable-features": "VizDisplayCompositor",
      "enable-automation": nil,
      "disable-background-timer-throttling": nil,
      "disable-renderer-backgrounding": nil,
      "disable-backgrounding-occluded-windows": nil
    },
    # Critical timeout settings - significantly increased for stability
    timeout: 120,            # Cuprite command timeout (increased from 60)
    process_timeout: 180,    # Process spawn timeout (increased from 120)
    # Use our Chrome wrapper with absolute path
    browser_path: "/app/chrome_wrapper.sh",
    headless: ENV["HEADLESS"] != "false",
    # Slow down operations for more stability in containers
    slowmo: ENV["CI"] ? 0.2 : 0.1,  # Added slowmo even for non-CI
    inspector: false,
    # Additional options to help with container stability
    ignore_https_errors: true,
    ignore_default_browser_options: false,
    # Set larger receive buffer
    ws_max_receive_size: 1024 * 1024 * 10, # 10MB
    # Temp directory configuration for Ferrum
    tmpdir: "/tmp/appuser-tmp",
    # Additional stability options
    xvfb: ENV["DISPLAY"] == ":99",
    # Retry failed commands
    retry_interval: 1.0,
    # Better modal handling
    pending_connection_errors: false
  }
  
  # Add ws_url_timeout if supported
  begin
    options[:ws_url_timeout] = 180  # Increased from 120 to give Chrome even more time
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
    
    # Try to access the driver to trigger browser startup with better error handling
    begin
      session = Capybara.current_session
      if session.respond_to?(:driver) && session.driver.respond_to?(:browser)
        puts "[SYSTEM_TEST] Starting browser for test: #{self.class.description}"
        
        # Try to start browser with retry logic
        retries = 3
        begin
          browser = session.driver.browser
          # Test browser connectivity
          browser.evaluate("1 + 1") if browser.respond_to?(:evaluate)
          puts "[SYSTEM_TEST] Browser started successfully"
        rescue => browser_error
          retries -= 1
          if retries > 0
            puts "[SYSTEM_TEST] Browser startup failed (#{browser_error.class.name}: #{browser_error.message}), retrying... (#{retries} attempts left)"
            sleep 2
            retry
          else
            raise browser_error
          end
        end
      end
    rescue => e
      puts "[SYSTEM_TEST] Error starting browser: #{e.class.name}: #{e.message}"
      puts "[SYSTEM_TEST] Backtrace:"
      puts e.backtrace.first(10).join("\n")
      
      # Only show logs on error for debugging
      if Dir.exist?("/tmp/chrome-logs")
        Dir.glob("/tmp/chrome-logs/*.log").each do |log_file|
          puts "[SYSTEM_TEST] Chrome log (#{log_file}):"
          content = File.read(log_file) rescue "could not read"
          puts content.split("\n").last(10).join("\n") # Last 10 lines instead of 5
        end
      end
      
      # Show Chrome processes for debugging
      begin
        processes = `ps aux | grep -i chrome` rescue "Could not get process list"
        puts "[SYSTEM_TEST] Chrome processes:"
        puts processes
      rescue
        # Ignore if ps command fails
      end
      
      raise e
    end
  end
  
  # Add after hook to clean up browser state
  config.after(:each, type: :system) do
    begin
      if Capybara.current_session.driver.respond_to?(:reset!)
        Capybara.current_session.driver.reset!
      end
    rescue => e
      puts "[SYSTEM_TEST] Warning: Could not reset driver: #{e.message}"
    end
  end
end
