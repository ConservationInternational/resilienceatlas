# == Schema Information
#
# Table name: journeys
#
#  id          :bigint           not null, primary key
#  credits     :string
#  credits_url :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  title       :string
#  subtitle    :string
#  theme       :text
#
class JourneySerializer < ActiveModel::Serializer
  include BlobSerializer

  cache key: "journey_#{I18n.locale}"
  attributes :title, :subtitle, :theme, :background_image, :credits, :credits_url
  has_many :journey_steps

  def background_image
    image_links_for object.background_image
  end
end
