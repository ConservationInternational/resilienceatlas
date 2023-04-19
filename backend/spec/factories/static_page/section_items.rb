# == Schema Information
#
# Table name: static_page_section_items
#
#  id          :bigint           not null, primary key
#  section_id  :bigint           not null
#  position    :integer          not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  title       :string
#  description :text
#
FactoryBot.define do
  factory :static_page_section_item, class: "StaticPage::SectionItem" do
    section factory: :static_page_section
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:description) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
    position { 1 }
  end
end
