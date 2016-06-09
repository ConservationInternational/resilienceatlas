FactoryGirl.define do
  sequence(:email) { |n| "person-#{n}@example.com" }

  factory :user, class: User do
    email     'pepe@sample.com'
    password  'password'
    password_confirmation { |u| u.password }
  end
end