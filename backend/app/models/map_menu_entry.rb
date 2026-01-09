# == Schema Information
#
# Table name: map_menu_entries
#
#  id         :bigint           not null, primary key
#  label      :string
#  link       :string
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ancestry   :string
#

class MapMenuEntry < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :label, touch: true, fallbacks_for_empty_translations: true
  end

  has_ancestry orphan_strategy: :destroy

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  if !defined?(Rails::Generators) && !(Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if ActiveRecord::Base.connection&.table_exists?(:map_menu_entries)
        translates :label, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :label

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :label, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping MapMenuEntry translations setup - database not ready"
    end
  end

  validates_presence_of :position

  def self.ransackable_attributes(auth_object = nil)
    %w[id label link position ancestry created_at updated_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[translations]
  end
end
