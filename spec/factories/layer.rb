FactoryBot.define do
  factory :layer do
    name { Faker::Lorem.word }
    slug { Faker::Lorem.word }
    layer_type { Faker::Lorem.word }
    zindex { 1 }
    active { true }
    order { 1 }
    color { '#000' }
    info { Faker::Lorem.word }
    interactivity { Faker::Lorem.word }
  end

  factory :with_source, class: Source do
    source_type { 'Info' }
    reference { Faker::Lorem.word }
    reference_short { Faker::Lorem.words(number: 2) }
    url { Faker::Internet.url }
    contact_name { Faker::Name.name }
    contact_email { Faker::Internet.email }
    license { Faker::Lorem.words(number: 2) }
    last_updated { Faker::Date.between(from: 100.days.ago, to: Date.today) }
    after(:create) do |with_source|
      FactoryBot.create(:layer, sources: [with_source])
    end
  end

  factory :source_layer, class: Source do
    source_type { 'Info' }
    reference { Faker::Lorem.word }
    reference_short { Faker::Lorem.words(number: 2) }
    url { Faker::Internet.url }
    contact_name { Faker::Name.name }
    contact_email { Faker::Internet.email }
    license { Faker::Lorem.words(number: 2) }
    last_updated { Faker::Date.between(from: 100.days.ago, to: Date.today) }
  end
end
