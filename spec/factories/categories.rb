FactoryBot.define do
  factory :category do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:slug) { |n| "Category-#{n}" }
    sequence(:description) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
  end
end
