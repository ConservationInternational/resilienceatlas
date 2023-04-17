FactoryBot.define do
  factory :static_page_section_paragraph, class: "StaticPage::SectionParagraph" do
    section factory: :static_page_section
    sequence(:text) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    image { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/picture.jpg"), "image/jpeg") }
    sequence(:image_position) do |n|
      StaticPage::SectionParagraph.image_positions.keys.sample random: Random.new(n)
    end
    sequence(:image_credits) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:image_credits_url) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Internet.url
    end
  end
end
