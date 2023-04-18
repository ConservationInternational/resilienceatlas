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
class StaticPage::SectionItemSerializer < ActiveModel::Serializer
  include BlobSerializer

  attributes :title, :description, :image, :position

  def image
    image_links_for object.image
  end
end
