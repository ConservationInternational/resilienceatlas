# == Schema Information
#
# Table name: homepages
#
#  id                :bigint           not null, primary key
#  credits_url       :string
#  position          :integer          default(1), not null
#  show_journeys     :boolean          default(FALSE), not null
#  journeys_position :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  subtitle          :string
#  credits           :string
#  journeys_title    :string
#
FactoryBot.define do
  factory :homepage do
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
    sequence(:journeys_title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
  end
end
