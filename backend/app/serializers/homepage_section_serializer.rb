class HomepageSectionSerializer < ActiveModel::Serializer
  include BlobSerializer

  attributes :title, :subtitle, :button_text, :button_url, :image_position, :image_credits, :image_credits_url,
    :background_color, :position, :image

  def image
    image_links_for object.image
  end
end
