FactoryBot.define do
  factory :admin_user do
    sequence(:email) { |n| "person-#{n}@example.com" }
    password { "password" }
    password_confirmation { "password" }
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.name
    end
    sequence(:nickname) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
