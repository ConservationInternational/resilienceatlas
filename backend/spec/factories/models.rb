# == Schema Information
#
# Table name: models
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         default(Tue, 28 Mar 2023 22:07:16.745569000 CEST +02:00), not null
#  updated_at     :datetime         default(Tue, 28 Mar 2023 22:07:16.746270000 CEST +02:00), not null
#  query_analysis :text
#  table_name     :string
#  name           :string
#  description    :text
#  source         :text
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
