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
class HomepageSection < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :title, :subtitle, :button_text, :image_credits, touch: true, fallbacks_for_empty_translations: true
  end

  belongs_to :homepage

  has_one_attached :image, service: :local_public

  enum :image_position, {left: "left", right: "right", cover: "cover"}, default: :left, prefix: true

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  unless defined?(Rails::Generators) || (Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if ActiveRecord::Base.connection&.table_exists?(:homepage_sections)
        translates :title, :subtitle, :button_text, :image_credits, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :title, :subtitle, :button_text, :image_credits

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
          translation_class.validates_presence_of :subtitle, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping HomepageSection translations setup - database not ready"
    end
  end

  validates :button_url, url: true
  validates :image_credits_url, url: true
  validates :position, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validates :image_position, presence: true
  validates :image, presence: true, content_type: /\Aimage\/.*\z/
end
