# == Schema Information
#
# Table name: journeys
#
#  id          :bigint           not null, primary key
#  credits     :string
#  credits_url :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  published   :boolean          default(FALSE), not null
#  title       :string
#  subtitle    :string
#  theme       :text
#
FactoryBot.define do
  factory :journey do
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
    sequence(:credits) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:credits_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:published) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    background_image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
    journey_steps { build_list :journey_step, 2, journey: nil }
  end
end
