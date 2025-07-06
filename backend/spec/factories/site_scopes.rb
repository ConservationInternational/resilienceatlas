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
      Faker::Internet.domain_word
    end
    has_analysis { false }
    password_protected { false }
    latitude { Faker::Address.latitude }
    longitude { Faker::Address.longitude }
    header_theme { ['ci-theme', 'vs-theme'].sample }
    zoom_level { rand(1..10) }
    linkback_text { Faker::Lorem.sentence }
    linkback_url { Faker::Internet.url }
    header_color { Faker::Color.hex_color }
    logo_url { Faker::Internet.url }
    predictive_model { false }
    analysis_options { false }
    has_gef_logo { false }

    trait :password_protected do
      password_protected { true }
      username { 'testuser' }
      password { 'password123' }
    end
  end
end
