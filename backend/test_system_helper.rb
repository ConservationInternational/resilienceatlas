#!/usr/bin/env ruby

# Simple test script to validate system_helper improvements
require_relative "spec/system_helper"

puts "Testing system helper configuration..."

# Test 1: Check if Capybara is configured properly
puts "✓ Capybara.default_max_wait_time: #{Capybara.default_max_wait_time}"
puts "✓ Capybara.enable_aria_label: #{Capybara.enable_aria_label}"
puts "✓ Capybara.automatic_reload: #{Capybara.automatic_reload}"

# Test 2: Check if driver is registered
puts "✓ Cuprite driver registered: #{Capybara.drivers.key?(:cuprite)}"

# Test 3: Check if Ferrum timeout is set
if defined?(Ferrum)
  browser = Ferrum::Browser.new
  puts "✓ Ferrum websocket timeout: #{browser.ws_url_timeout}"
  puts "✓ Ferrum command timeout: #{browser.command_timeout}"
  browser.quit
else
  puts "⚠ Ferrum not available"
end

puts "System helper configuration test completed!"
