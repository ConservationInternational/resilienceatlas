# == Schema Information
#
# Table name: map_menu_entries
#
#  id         :bigint           not null, primary key
#  label      :string
#  link       :string
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ancestry   :string
#
FactoryBot.define do
  factory :map_menu_entry do
    sequence(:label) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.name
    end
    sequence(:link) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:position) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
  end
end
