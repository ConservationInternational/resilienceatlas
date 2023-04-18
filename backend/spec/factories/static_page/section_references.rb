FactoryBot.define do
  factory :static_page_section_reference, class: "StaticPage::SectionReference" do
    section factory: :static_page_section
    sequence(:slug) { |n| "StaticPageReference-#{n}" }
    sequence(:text) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.paragraph
    end
    position { 1 }
  end
end
