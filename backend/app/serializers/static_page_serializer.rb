class StaticPageSerializer < ActiveModel::Serializer
  include BlobSerializer

  cache key: "static_page_#{I18n.locale}"
  attributes :title, :slug, :image, :image_credits, :image_credits_url
  has_many :sections, serializer: StaticPage::SectionSerializer do |serializer|
    serializer.object.sections.order :position
  end

  def image
    image_links_for object.image
  end
end
