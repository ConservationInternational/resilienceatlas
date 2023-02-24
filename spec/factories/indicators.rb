# == Schema Information
#
# Table name: indicators
#
#  id          :bigint           not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Wed, 22 Feb 2023 12:02:20.466026000 CET +01:00), not null
#  updated_at  :datetime         default(Wed, 22 Feb 2023 12:02:20.474090000 CET +01:00), not null
#  category_id :integer
#  position    :integer
#  column_name :string
#  operation   :string
#
FactoryBot.define do
  factory :indicator do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:slug) { |n| "Category-#{n}" }
    sequence(:version) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    category
    sequence(:position) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:column_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:operation) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
