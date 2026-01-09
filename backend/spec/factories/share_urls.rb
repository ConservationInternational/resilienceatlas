# == Schema Information
#
# Table name: share_urls
#
#  id         :bigint           not null, primary key
#  uid        :string
#  body       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :share_url do
    sequence(:uid) { |n| "UID-#{n}" }
    sequence(:body) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
  end
end
