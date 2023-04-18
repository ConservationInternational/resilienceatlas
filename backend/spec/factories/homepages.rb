# == Schema Information
#
# Table name: homepages
#
#  id                  :bigint           not null, primary key
#  homepage_journey_id :bigint
#  site_scope_id       :bigint           not null
#  credits_url         :string
#  show_journeys       :boolean          default(FALSE), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  title               :string
#  subtitle            :string
#  credits             :string
#
FactoryBot.define do
  factory :homepage do
    site_scope
    homepage_journey
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
  end
end
