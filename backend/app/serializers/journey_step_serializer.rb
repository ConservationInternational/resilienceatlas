# == Schema Information
#
# Table name: journey_steps
#
#  id               :bigint           not null, primary key
#  step_type        :string           not null
#  credits          :string
#  credits_url      :string
#  source           :string
#  mask_sql         :string
#  map_url          :string
#  embedded_map_url :string
#  background_color :string
#  chapter_number   :integer
#  position         :integer          default(1), not null
#  journey_id       :bigint           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  title            :string
#  subtitle         :string
#  description      :string
#  content          :text
#
class JourneyStepSerializer < ActiveModel::Serializer
  include BlobSerializer

  cache key: "journey_step_#{I18n.locale}"
  attributes :id, :step_type, :position

  # attributes which visibility depends on journey step type
  %i[title subtitle description content chapter_number credits credits_url source mask_sql map_url embedded_map_url background_color background_image].each do |attr|
    attribute attr, if: -> { JourneyStep::AVAILABLE_FIELDS_FOR_EVERY_TYPE[attr][:available_at].include? object.step_type.to_sym }
  end

  def background_image
    image_links_for object.background_image
  end
end
