FactoryGirl.define do
  factory :layer do
    name Faker::Lorem.word
    slug Faker::Lorem.word
    layer_type Faker::Lorem.word
    zindex 1
    active true
    order 1
    color '#000'
    info Faker::Lorem.word
    interactivity Faker::Lorem.word
  end
end
