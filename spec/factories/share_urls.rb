FactoryBot.define do
  factory :share_url do
    sequence(:uid) { |n| "UID-#{n}" }
    sequence(:body) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
  end
end
