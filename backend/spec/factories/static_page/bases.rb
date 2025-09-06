# == Schema Information
#
# Table name: static_page_bases
#
#  id                :bigint           not null, primary key
#  slug              :string           not null
#  image_credits_url :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  image_credits     :string
#
FactoryBot.define do
  factory :static_page, class: "StaticPage::Base" do
    sequence(:slug) { |n| "StaticPage-#{n}" }
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
    sequence(:image_credits) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:image_credits_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
  end
end
