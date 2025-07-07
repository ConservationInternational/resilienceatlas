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
class JourneyStep < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :title, :subtitle, :description, :content, :credits, :source, touch: true, fallbacks_for_empty_translations: true
  end

  AVAILABLE_FIELDS_FOR_EVERY_TYPE = { # dont forget to add/remove fields to/from Admin and API
    title: {available_at: %i[landing conclusion chapter embed]},
    subtitle: {available_at: %i[conclusion embed]},
    description: {available_at: %i[landing chapter]},
    content: {available_at: %i[conclusion embed]},
    chapter_number: {available_at: %i[chapter]},
    credits: {available_at: %i[landing conclusion chapter]},
    credits_url: {available_at: %i[landing conclusion chapter]},
    source: {available_at: %i[embed]},
    mask_sql: {available_at: %i[embed]},
    map_url: {available_at: %i[embed]},
    embedded_map_url: {available_at: %i[embed]},
    position: {available_at: %i[landing conclusion chapter embed]},
    background_color: {available_at: %i[conclusion chapter]},
    background_image: {available_at: %i[landing conclusion chapter]}
  }.freeze

  belongs_to :journey

  has_rich_text :content

  has_one_attached :background_image, service: :local_public

  enum :step_type, {landing: "landing", conclusion: "conclusion", chapter: "chapter", embed: "embed"}, default: :landing

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  unless defined?(Rails::Generators) || (Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if ActiveRecord::Base.connection&.table_exists?(:journey_steps)
        translates :title, :subtitle, :description, :content, :credits, :source, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :title, :subtitle, :description, :content, :credits, :source
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping JourneyStep translations setup - database not ready"
    end
  end

  validates :background_image, content_type: /\Aimage\/.*\z/
  validates :credits_url, url: true
end
