FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "person-#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
    sequence(:first_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.first_name
    end
    sequence(:last_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.last_name
    end
    sequence(:phone) do |n|
      Faker::Config.random = Random.new(n)
      Faker::PhoneNumber.phone_number
    end
    sequence(:organization) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:organization_role) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
