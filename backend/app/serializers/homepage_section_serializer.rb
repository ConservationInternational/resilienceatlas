# == Schema Information
#
# Table name: homepage_sections
#
#  id                :bigint           not null, primary key
#  homepage_id       :bigint           not null
#  button_url        :string
#  image_position    :string
#  image_credits_url :string
#  background_color  :string
#  position          :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string
#  subtitle          :string
#  button_text       :string
#  image_credits     :string
#
class HomepageSectionSerializer < ActiveModel::Serializer
  include BlobSerializer

  attributes :title, :subtitle, :button_text, :button_url, :image_position, :image_credits, :image_credits_url,
    :background_color, :position, :image

  def image
    image_links_for object.image
  end
end
