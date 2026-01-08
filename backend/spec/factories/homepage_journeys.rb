# == Schema Information
#
# Table name: homepage_journeys
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  title      :string
#
FactoryBot.define do
  factory :homepage_journey do
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
  end
end
