# == Schema Information
#
# Table name: user_downloads
#
#  id         :bigint           not null, primary key
#  subdomain  :string
#  user_id    :integer
#  layer_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :user_download do
    sequence(:subdomain) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    user
    layer
  end
end
