class HomepageSerializer < ActiveModel::Serializer
  include BlobSerializer

  cache key: "homepage_#{I18n.locale}"
  attributes :title, :subtitle, :background_image, :credits, :credits_url
  belongs_to :homepage_journey
  has_many :homepage_sections do |serializer|
    serializer.object.homepage_sections.order :position
  end

  def background_image
    image_links_for object.background_image
  end
end
