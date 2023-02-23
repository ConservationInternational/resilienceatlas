# == Schema Information
#
# Table name: identities
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  provider   :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

FactoryBot.define do
  factory :identity do
    user { nil }
    sequence(:provider) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:uid) { |n| "UID-#{n}" }
  end
end
