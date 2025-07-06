# == Schema Information
#
# Table name: indicators
#
#  id          :bigint           not null, primary key
#  slug        :string           not null
#  version     :string
#  created_at  :datetime         default(Tue, 28 Mar 2023 22:07:16.747487000 CEST +02:00), not null
#  updated_at  :datetime         default(Tue, 28 Mar 2023 22:07:16.747956000 CEST +02:00), not null
#  category_id :integer
#  position    :integer
#  column_name :string
#  operation   :string
#  name        :string
#

class Indicator < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :name, touch: true, fallbacks_for_empty_translations: true
  end

  has_and_belongs_to_many :models
  belongs_to :category

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  unless defined?(Rails::Generators) || Rails.env.test? && ENV['RAILS_MIGRATE']
    begin
      if ActiveRecord::Base.connection && ActiveRecord::Base.connection.table_exists?(:indicators)
        translates :name, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :name
        
        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping Indicator translations setup - database not ready: #{e.message}"
    end
  end

  validates_presence_of :slug

  acts_as_list scope: :category

  def self.fetch_all(options = {})
    Indicator.with_translations
  end
end
