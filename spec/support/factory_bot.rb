RSpec.configure do |config|
  config.after do
    FactoryBot.rewind_sequences
  end
end
