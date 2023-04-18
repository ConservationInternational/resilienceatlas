# == Schema Information
#
# Table name: static_page_section_paragraphs
#
#  id                :bigint           not null, primary key
#  section_id        :bigint           not null
#  image_position    :string           not null
#  image_credits_url :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  text              :text
#  image_credits     :string
#
class StaticPage::SectionParagraphSerializer < ActiveModel::Serializer
  include BlobSerializer

  attributes :text, :image, :image_credits, :image_credits_url, :image_position

  def image
    image_links_for object.image
  end
end
