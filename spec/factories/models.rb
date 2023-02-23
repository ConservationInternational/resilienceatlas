FactoryBot.define do
  factory :model do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:description) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:source) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:query_analysis) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:table_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
