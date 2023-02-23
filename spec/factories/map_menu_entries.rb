#  label      :string
#  link       :string
#  position   :integer

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
