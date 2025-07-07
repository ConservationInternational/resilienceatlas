# == Schema Information
#
# Table name: homepage_journeys
#
#  id         :bigint           not null, primary key
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  title      :string
#
class HomepageJourney < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :title, :subtitle, touch: true, fallbacks_for_empty_translations: true
  end

  has_one :homepage, dependent: :nullify

  # Translation setup - protected against migration errors
  begin
    translates :title, touch: true, fallbacks_for_empty_translations: true
    active_admin_translates :title
    
    # Only add translation validations if the translation_class is defined
    if respond_to?(:translation_class) && translation_class
      translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
    end
  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
    # Database not available yet - skip translation setup for now
    Rails.logger&.info "Skipping HomepageJourney translations setup - database not ready: #{e.message}"
  end

  validates :position, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
end
