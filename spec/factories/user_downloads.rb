FactoryBot.define do
  factory :user_download do
    sequence(:site_scope) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    user
    layer
  end
end
