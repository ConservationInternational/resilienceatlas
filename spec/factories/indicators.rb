FactoryBot.define do
  factory :indicator do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:slug) { |n| "Category-#{n}" }
    sequence(:version) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    category
    sequence(:position) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:column_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:operation) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
