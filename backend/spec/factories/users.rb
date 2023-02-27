# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  reset_password_token   :string
#  reset_password_sent_at :datetime
#  remember_created_at    :datetime
#  sign_in_count          :integer          default(0), not null
#  current_sign_in_at     :datetime
#  last_sign_in_at        :datetime
#  current_sign_in_ip     :inet
#  last_sign_in_ip        :inet
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  first_name             :string
#  last_name              :string
#  phone                  :string
#  organization           :string
#  organization_role      :string
#
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "person-#{n}@example.com" }
    password { "password" }
    password_confirmation { "password" }
    sequence(:first_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.first_name
    end
    sequence(:last_name) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Name.last_name
    end
    sequence(:phone) do |n|
      Faker::Config.random = Random.new(n)
      Faker::PhoneNumber.phone_number
    end
    sequence(:organization) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
    sequence(:organization_role) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.word
    end
  end
end
