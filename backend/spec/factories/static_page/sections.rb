# == Schema Information
#
# Table name: static_page_sections
#
#  id                 :bigint           not null, primary key
#  static_page_id     :bigint           not null
#  position           :integer          not null
#  slug               :string
#  section_type       :string           not null
#  title_size         :integer          default(2)
#  show_at_navigation :boolean          default(FALSE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  title              :string
#
FactoryBot.define do
  factory :static_page_section, class: "StaticPage::Section" do
    static_page
    position { 1 }
    sequence(:slug) { |n| "StaticPageSection-#{n}" }
    sequence(:section_type) do |n|
      StaticPage::Section.section_types.keys.sample random: Random.new(n)
    end
    sequence(:title) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Lorem.sentence
    end
    sequence(:title_size) do |n|
      (1..5).to_a.sample random: Random.new(n)
    end
    sequence(:show_at_navigation) do |n|
      Faker::Config.random = Random.new(n)
      Faker::Boolean.boolean
    end
  end
end
