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
class StaticPage::SectionReferenceSerializer < ActiveModel::Serializer
  attributes :slug, :text, :position
end
