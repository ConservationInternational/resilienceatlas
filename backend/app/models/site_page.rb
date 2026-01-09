# == Schema Information
#
# Table name: site_pages
#
#  id            :bigint           not null, primary key
#  title         :string
#  body          :text
#  priority      :integer
#  site_scope_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  slug          :string
#

class SitePage < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :title, :body, touch: true, fallbacks_for_empty_translations: true
  end

  belongs_to :site_scope

  has_rich_text :body

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  if !defined?(Rails::Generators) && !(Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if ActiveRecord::Base.connection&.table_exists?(:site_pages)
        translates :title, :body, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :title, :body

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :title, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping SitePage translations setup - database not ready"
    end
  end

  validates_presence_of :site_scope, :slug

  def self.ransackable_attributes(auth_object = nil)
    %w[id title body priority site_scope_id created_at updated_at slug]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[site_scope translations]
  end
end
