require "system_helper"

RSpec.describe "JS diagnostic", type: :system do
  let(:admin_user) { create :admin_user }

  it "captures console errors on admin page load" do
    errors = []
    logs = []

    # Capture browser console messages via CDP
    begin
      page.driver.browser.on("Runtime.consoleAPICalled") do |event|
        type = event.dig("type") || "log"
        args = (event.dig("args") || []).map { |a| a["value"] || a["description"] || "" }.join(" ")
        if %w[error warning].include?(type)
          errors << "[#{type.upcase}] #{args}"
        else
          logs << "[#{type.upcase}] #{args}"
        end
      end
    rescue => e
      puts "Could not attach console listener: #{e.message}"
    end

    login_as admin_user

    # Visit a page that uses has_many (homepages)
    visit "/admin/homepages"
    sleep 2

    # Click new to load the form
    find("a.new_link", match: :first).click
    sleep 3

    # Report collected info
    puts "\n=== JS LOGS ==="
    logs.last(20).each { |l| puts l }
    puts "\n=== JS ERRORS ==="
    errors.each { |e| puts e }
    puts "==="

    # Check what modules actually loaded by querying window state
    rails_loaded = page.evaluate_script("window._rails_loaded")
    trix_defined = page.evaluate_script("typeof customElements !== 'undefined' && !!customElements.get('trix-editor')")
    window_trix = page.evaluate_script("typeof window.Trix !== 'undefined'")

    puts "\n=== JS STATE ==="
    puts "window._rails_loaded: #{rails_loaded}"
    puts "trix-editor defined: #{trix_defined}"
    puts "window.Trix defined: #{window_trix}"
    puts "==="

    # This test just gathers diagnostics - always passes
    expect(true).to be true
  end
end
