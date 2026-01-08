# == Schema Information
#
# Table name: static_page_section_references
#
#  id         :bigint           not null, primary key
#  section_id :bigint           not null
#  slug       :string
#  position   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  text       :text
#
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
