require "webmock/rspec"
require "rspec/retry"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  # config.profile_examples = 10

  # show retry status in spec process
  config.verbose_retry = true
  # show exception that triggers a retry if verbose_retry is set to true
  config.display_try_failure_messages = true

  # run retry only on system specs
  config.around :each, type: :system do |ex|
    ex.run_with_retry retry: 3
  end

  # callback to be run between retries
  config.retry_callback = proc do |ex|
    if ex.metadata[:type] == :system
      # Force cuprite driver and prevent any selenium fallback
      Capybara.current_driver = :cuprite
      # Only reset if we successfully have cuprite driver
      if Capybara.current_driver == :cuprite
        begin
          Capybara.current_session.reset!
        rescue => e
          puts "[RETRY] Warning: Could not reset session: #{e.message}"
          # If reset fails, quit and force cuprite again
          begin
            Capybara.current_session.quit
            Capybara.current_driver = :cuprite
          rescue => quit_error
            puts "[RETRY] Warning: Could not quit session: #{quit_error.message}"
          end
        end
      end
    end
  end

  config.order = :random
  Kernel.srand config.seed
end
