# == Schema Information
#
# Table name: journeys
#
#  id          :bigint           not null, primary key
#  credits     :string
#  credits_url :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  published   :boolean          default(FALSE), not null
#  title       :string
#  subtitle    :string
#  theme       :text
#
class Journey < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :title, :subtitle, :theme, :credits, touch: true, fallbacks_for_empty_translations: true
  end

  has_many :journey_steps, dependent: :destroy

  has_one_attached :background_image, service: :local_public

  # Translation setup - only add extra features if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  if !defined?(Rails::Generators) && !(Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if defined?(Globalize) && ActiveRecord::Base.connection&.table_exists?(:journeys)
        active_admin_translates :title, :subtitle, :theme, :credits

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip extra translation setup for now
      Rails.logger&.info "Skipping Journey extra translations setup - database not ready"
    end
  end

  validates :background_image, content_type: /\Aimage\/.*\z/
  validates :credits_url, url: true

  after_save :at_least_one_step

  accepts_nested_attributes_for :journey_steps, allow_destroy: true

  scope :only_published, -> { where published: true }

  private

  # Validation of presence of relation(s) which is updated via nested attributes and contains translated attributes needs to be done
  # after save, otherwise the old translations are loaded from database at time of validation and they overwrite the new ones before they get saved.
  def at_least_one_step
    return if journey_steps.exists?

    errors.add :journey_steps, :blank
    raise ActiveRecord::Rollback
  end
end
