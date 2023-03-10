class JourneyStepSerializer < ActiveModel::Serializer
  include BlobSerializer

  cache key: "journey_step_#{I18n.locale}"
  attributes :id, :step_type, :position

  # attributes which visibility depends on journey step type
  %i[title subtitle theme content chapter_number credits credits_url map_theme mask_sql map_url btn_url background_color background_image].each do |attr|
    attribute attr, if: -> { JourneyStep::AVAILABLE_FIELDS_FOR_EVERY_TYPE[attr][:available_at].include? object.step_type.to_sym }
  end

  def background_image
    image_links_for object.background_image
  end
end
