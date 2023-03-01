# == Schema Information
#
# Table name: layer_groups
#
#  id               :bigint           not null, primary key
#  super_group_id   :integer
#  slug             :string
#  layer_group_type :string
#  category         :string
#  active           :boolean
#  order            :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  icon_class       :string
#  site_scope_id    :integer          default(1)
#  layer_group_id   :bigint           not null
#  name             :string
#  info             :text
#
FactoryBot.define do
  factory :layer_group do
    super_group { nil }
    site_scope
    sequence(:slug) { |n| "LayerGroup-#{n}" }
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:info) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:layer_group_type) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:category) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:active) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:order) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:icon_class) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
