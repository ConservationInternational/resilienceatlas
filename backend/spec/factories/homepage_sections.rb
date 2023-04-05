# == Schema Information
#
# Table name: homepage_sections
#
#  id                :bigint           not null, primary key
#  homepage_id       :bigint           not null
#  button_url        :string
#  image_position    :string
#  image_credits_url :string
#  background_color  :string
#  position          :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  subtitle          :string
#  button_text       :string
#  image_credits     :string
#
FactoryBot.define do
  factory :homepage_section do
    homepage
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:subtitle) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:button_text) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:button_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
    sequence(:image_position) do |n|
      HomepageSection.image_positions.keys.sample random: Random.new(n)
    end
    sequence(:background_color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
  end
end
