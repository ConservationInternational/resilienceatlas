# == Schema Information
#
# Table name: layers
#
#  id                        :bigint           not null, primary key
#  layer_group_id            :integer
#  slug                      :string           not null
#  layer_type                :string
#  zindex                    :integer
#  active                    :boolean
#  order                     :integer
#  color                     :string
#  layer_provider            :string
#  css                       :text
#  interactivity             :text
#  opacity                   :float
#  query                     :text
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  locate_layer              :boolean          default(FALSE)
#  icon_class                :string
#  published                 :boolean          default(TRUE)
#  zoom_max                  :integer          default(100)
#  zoom_min                  :integer          default(0)
#  dashboard_order           :integer
#  download                  :boolean          default(FALSE)
#  dataset_shortname         :string
#  dataset_source_url        :text
#  start_date                :datetime
#  end_date                  :datetime
#  spatial_resolution        :string
#  spatial_resolution_units  :string
#  temporal_resolution       :string
#  temporal_resolution_units :string
#  update_frequency          :string
#  version                   :string
#  analysis_suitable         :boolean          default(FALSE)
#  analysis_query            :text
#  layer_config              :text
#  analysis_body             :text
#  interaction_config        :text
#  name                      :string
#  info                      :text
#  legend                    :text
#  title                     :string
#  data_units                :string
#  processing                :string
#  description               :text
#
FactoryBot.define do
  factory :layer do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:slug) { |n| "Layer-#{n}" }
    sequence(:layer_type) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:zindex) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:active) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:order) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    sequence(:info) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:interactivity) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
