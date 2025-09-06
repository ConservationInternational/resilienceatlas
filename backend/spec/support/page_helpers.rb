require "timeout"

module PageHelpers
  def t(...)
    I18n.t(...)
  end

  def login_as(admin_user, password: nil)
    visit admin_root_path

    safe_fill_in "admin_user[email]", with: admin_user.email
    safe_fill_in "admin_user[password]", with: password || admin_user.password

    safe_click "input[value='Login']"

    # Wait for successful login
    expect(page).to have_current_path(admin_root_path, wait: 15)
  end

  # Wait for an element to be present and visible
  def wait_for_element(selector, timeout: Capybara.default_max_wait_time)
    find(selector, wait: timeout)
  end

  # Fill in a field with better error handling
  def safe_fill_in(field, with:, wait: 10)
    # First wait for the field to exist
    field_element = find_field(field, wait: wait)

    # Make sure it's visible and enabled
    expect(field_element).to be_visible
    expect(field_element).not_to be_disabled

    # Clear and fill
    field_element.set(with)
  end

  # Click with better waiting
  def safe_click(selector, wait: 10)
    element = find(selector, wait: wait)
    expect(element).to be_visible
    element.click
  end

  # Handle modals with retry logic for Cuprite
  def safe_accept_confirm(wait: 10, &block)
    # For Cuprite, we need to handle modals differently
    if Capybara.current_driver == :cuprite
      # Use Capybara's accept_confirm but with better error handling for Cuprite
      begin
        accept_confirm(wait: wait, &block)
      rescue Capybara::ModalNotFound
        puts "[SYSTEM_TEST] Modal not found with accept_confirm, trying alternative approach"

        # Alternative approach: Execute the action and handle any JavaScript confirm
        page.execute_script <<~JS
          window.confirm = function(msg) {
            console.log('Confirm dialog: ' + msg);
            return true;
          };
        JS

        # Execute the block
        result = block.call

        # Wait a moment for any async operations
        sleep 1

        result
      end
    else
      # Use Capybara's standard accept_confirm for other drivers
      accept_confirm(wait: wait, &block)
    end
  end

  # Wait for page to be fully loaded
  def wait_for_page_load(timeout: 30)
    # Wait for document ready state
    expect(page).to have_no_css(".loading", wait: timeout)

    # Wait for any ajax requests to complete (if using jQuery)
    begin
      wait_for { page.evaluate_script("jQuery.active == 0") } if page.evaluate_script('typeof jQuery !== "undefined"')
    rescue
      # jQuery might not be available, that's ok
    end

    # Give a small buffer for rendering
    sleep 0.2
  end

  # Handle Rails UJS links with method attributes (PUT, DELETE, etc.)
  def safe_click_method_link(text_or_selector, method: :get, wait: 10)
    element = if text_or_selector.is_a?(String) && text_or_selector.include?("href")
      # It's a CSS selector
      find(text_or_selector, wait: wait)
    else
      # It's link text
      find_link(text_or_selector, wait: wait)
    end

    expect(element).to be_visible

    # For PUT/DELETE links in ActiveAdmin, they usually have data-method attribute
    if method != :get
      # Check if it's a Rails UJS link with data-method
      if element["data-method"]
        # Let Rails UJS handle it
        element.click
      else
        # Manually construct the form submission for method-based requests
        href = element["href"]
        page.execute_script <<~JS
          var form = document.createElement('form');
          form.method = 'POST';
          form.action = '#{href}';
          
          var methodInput = document.createElement('input');
          methodInput.type = 'hidden';
          methodInput.name = '_method';
          methodInput.value = '#{method.upcase}';
          form.appendChild(methodInput);
          
          var csrfInput = document.createElement('input');
          csrfInput.type = 'hidden';
          csrfInput.name = 'authenticity_token';
          csrfInput.value = document.querySelector('meta[name="csrf-token"]').content;
          form.appendChild(csrfInput);
          
          document.body.appendChild(form);
          form.submit();
        JS
      end
    else
      element.click
    end
  end

  private

  def wait_for(timeout: 10, &block)
    Timeout.timeout(timeout) do
      loop do
        return if block.call
        sleep 0.1
      end
    end
  rescue Timeout::Error
    raise "Condition not met within #{timeout} seconds"
  end
end
