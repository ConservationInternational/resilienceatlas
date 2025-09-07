# == Schema Information
#
# Table name: journey_steps
#
#  id               :bigint           not null, primary key
#  step_type        :string           not null
#  credits          :string
#  credits_url      :string
#  source           :string
#  mask_sql         :string
#  map_url          :string
#  embedded_map_url :string
#  background_color :string
#  chapter_number   :integer
#  position         :integer          default(1), not null
#  journey_id       :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  title            :string
#  subtitle         :string
#  description      :string
#  content          :text
#
FactoryBot.define do
  factory :journey_step do
    journey
    sequence(:step_type) do |n|
      JourneyStep.step_types.keys.sample random: Random.new(n)
    end
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:subtitle) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:description) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:content) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:chapter_number) { |n| n }
    sequence(:credits) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:credits_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:source) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:mask_sql) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:map_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:embedded_map_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:position) { |n| n }
    sequence(:background_color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    background_image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
  end
end
