FactoryBot.define do
  factory :journey_step do
    journey
    sequence(:step_type) do |n|
      JourneyStep.step_types.keys.sample random: Random.new(n)
    end
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:subtitle) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:theme) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:content) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:chapter_number) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:credits) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:credits_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:map_theme) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:mask_sql) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:map_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:btn_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:position) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:background_color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    background_image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
  end
end
