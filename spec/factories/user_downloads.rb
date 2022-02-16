FactoryBot.define do
  factory :user_download do
    site_scope { "MyString" }
    user_id { 1 }
    layer_id { 1 }
  end
end
