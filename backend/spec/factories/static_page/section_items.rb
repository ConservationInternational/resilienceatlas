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
