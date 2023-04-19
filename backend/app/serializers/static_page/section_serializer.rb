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
class StaticPage::SectionSerializer < ActiveModel::Serializer
  attributes :title, :slug, :title_size, :section_type, :show_at_navigation, :position

  has_one :section_paragraph, serializer: StaticPage::SectionParagraphSerializer
  has_many :section_items, serializer: StaticPage::SectionItemSerializer do |serializer|
    serializer.object.section_items.order :position
  end
  has_many :section_references, serializer: StaticPage::SectionReferenceSerializer do |serializer|
    serializer.object.section_references.order :position
  end
end
