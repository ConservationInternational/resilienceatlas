# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  name        :string
#  description :text
#
FactoryBot.define do
  factory :category do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:slug) { |n| "Category-#{n}" }
    sequence(:description) do |n|
      "Description for category #{n}. This is a consistent test description."
    end
  end
end
