# == Schema Information
#
# Table name: sources
#
#  id                       :bigint           not null, primary key
#  source_type              :string
#  reference                :string
#  reference_short          :string
#  url                      :string
#  contact_name             :string
#  contact_email            :string
#  license                  :string
#  last_updated             :datetime
#  version                  :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  spatial_resolution_units :string
#  license_url              :text
#

FactoryBot.define do
  factory :source do
    sequence(:source_type) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:reference) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:reference_short) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:contact_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.name
    end
    sequence(:contact_email) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.email
    end
    sequence(:license) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.words(number: 2)
    end
    sequence(:last_updated) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Date.between(from: 100.days.ago, to: Date.today)
    end
    sequence(:version) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:spatial_resolution_units) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:license_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
  end
end
