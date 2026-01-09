# == Schema Information
#
# Table name: feedbacks
#
#  id         :bigint           not null, primary key
#  language   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :feedback do
    sequence(:language) do |n|
      I18n.available_locales.sample random: Random.new(n)
    end
  end
end
