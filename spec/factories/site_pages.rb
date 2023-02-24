# == Schema Information
#
# Table name: site_pages
#
#  id            :bigint           not null, primary key
#  title         :string
#  body          :text
#  priority      :integer
#  site_scope_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  slug          :string
#

FactoryBot.define do
  factory :site_page do
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:body) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    sequence(:priority) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Number.between from: 1, to: 100
    end
    site_scope { nil }
    sequence(:slug) { |n| "SitePage-#{n}" }
  end
end
