FactoryBot.define do
  factory :site_scope do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.name
    end
    sequence(:color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    sequence(:subdomain) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:has_analysis) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:latitude) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Address.latitude
    end
    sequence(:longitude) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Address.longitude
    end
    sequence(:header_theme) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:zoom_level) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:linkback_text) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:linkback_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:header_color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    sequence(:logo_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:predictive_model) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:analysis_options) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
  end
end
