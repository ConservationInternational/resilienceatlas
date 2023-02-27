# == Schema Information
#
# Table name: site_scopes
#
#  id               :bigint           not null, primary key
#  name             :string
#  color            :string
#  subdomain        :string
#  has_analysis     :boolean          default(FALSE)
#  latitude         :float
#  longitude        :float
#  header_theme     :string
#  zoom_level       :integer          default(3)
#  linkback_text    :text
#  linkback_url     :text
#  header_color     :string
#  logo_url         :text
#  predictive_model :boolean          default(FALSE), not null
#  analysis_options :boolean          default(FALSE), not null
#  analytics_code   :string
#  has_gef_logo     :boolean
#
FactoryBot.define do
  factory :site_scope do
    sequence(:name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.name
    end
    sequence(:color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    sequence(:subdomain) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:has_analysis) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:latitude) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Address.latitude
    end
    sequence(:longitude) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Address.longitude
    end
    sequence(:header_theme) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:zoom_level) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    sequence(:linkback_text) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:linkback_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:header_color) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Color.hex_color
    end
    sequence(:logo_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
    sequence(:predictive_model) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
    sequence(:analysis_options) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
  end
end
