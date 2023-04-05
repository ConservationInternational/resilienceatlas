FactoryBot.define do
  factory :homepage do
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:subtitle) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:credits) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:credits_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    background_image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
    sequence(:show_journeys) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:journeys_title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
  end
end
