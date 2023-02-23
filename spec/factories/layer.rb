FactoryBot.define do
  factory :layer do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:slug) { |n| "Layer-#{n}" }
    sequence(:layer_type) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:zindex) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:active) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:order) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    sequence(:info) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:interactivity) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
