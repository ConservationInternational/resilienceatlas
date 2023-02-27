# == Schema Information
#
# Table name: models
#
#  id             :bigint           not null, primary key
#  name           :string           not null
#  description    :text
#  source         :text
#  created_at     :datetime         default(Wed, 22 Feb 2023 12:02:20.403696000 CET +01:00), not null
#  updated_at     :datetime         default(Wed, 22 Feb 2023 12:02:20.453249000 CET +01:00), not null
#  query_analysis :text
#  table_name     :string
#
FactoryBot.define do
  factory :model do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:description) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:source) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:query_analysis) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:table_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
