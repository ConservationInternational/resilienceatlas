RSpec.configure do |config|
  config.after do
    FactoryBot.rewind_sequences
  end
  
  # Ensure FactoryBot uses deterministic random data
  config.before(:suite) do
    # Use the same seed as RSpec for consistent factory data generation
    FactoryBot.define do
      sequence :id do |n|
        n
      end
    end
    # Seed Faker for consistent fake data in factories
    Faker::Config.random = Random.new(1584)
    srand(1584)
  end
  
  config.before(:each) do
    # Reset randomness before each test for consistency
    srand(1584)
    Faker::Config.random = Random.new(1584)
  end
end
