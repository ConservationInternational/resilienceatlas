# == Schema Information
#
# Table name: photos
#
#  id         :bigint           not null, primary key
#  image_data :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :photo do
    # Photo uses Shrine uploader with image_data field
    # For testing, we can leave image_data as nil or provide minimal data
    image_data { nil }
  end
end
