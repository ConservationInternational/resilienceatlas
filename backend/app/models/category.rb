# == Schema Information
#
# Table name: categories
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  name        :string
#  description :text
#

class Category < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :name, :description, touch: true, fallbacks_for_empty_translations: true
  end

  has_many :indicators

  # Translation setup - only add extra features if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  if !defined?(Rails::Generators) && !(Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if defined?(Globalize) && ActiveRecord::Base.connection&.table_exists?(:category_translations)
        active_admin_translates :name, :description

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
      # Database not available yet - skip extra translation setup for now
      Rails.logger&.info "Skipping Category extra translations setup - database not ready: #{e.message}"
    end
  end

  validates_presence_of :slug

  # Ransack configuration - explicitly allowlist searchable attributes for security
  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "id", "id_value", "slug", "updated_at", "name", "description"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["indicators", "translations"]
  end

  def self.fetch_all(options = {})
    Category.with_translations
  end
end
