FactoryBot.define do
  factory :feedback do
    sequence(:language) do |n|
      I18n.available_locales.sample random: Random.new(n)
    end
  end
end
