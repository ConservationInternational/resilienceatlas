# == Schema Information
#
# Table name: models
#
#  id             :bigint           not null, primary key
#  created_at     :datetime         default(Tue, 28 Mar 2023 22:07:16.745569000 CEST +02:00), not null
#  updated_at     :datetime         default(Tue, 28 Mar 2023 22:07:16.746270000 CEST +02:00), not null
#  query_analysis :text
#  table_name     :string
#  name           :string
#  description    :text
#  source         :text
#

class Model < ApplicationRecord
  # Always include basic globalize support if available
  # This ensures create_translation_table! is available for migrations
  if defined?(Globalize)
    translates :name, :description, :source, touch: true, fallbacks_for_empty_translations: true
  end

  has_and_belongs_to_many :site_scopes
  has_and_belongs_to_many :indicators

  # Translation setup - only initialize if database is ready and not during migration
  # This prevents errors during migrations when tables don't exist yet
  unless defined?(Rails::Generators) || (Rails.env.test? && ENV["RAILS_MIGRATE"])
    begin
      if ActiveRecord::Base.connection&.table_exists?(:models)
        translates :name, :description, :source, touch: true, fallbacks_for_empty_translations: true
        active_admin_translates :name, :description, :source

        # Only add translation validations if the translation_class is defined
        if respond_to?(:translation_class) && translation_class
          translation_class.validates_presence_of :name, if: -> { locale.to_s == I18n.default_locale.to_s }
        end
      end
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
      # Database not available yet - skip translation setup for now
      Rails.logger&.info "Skipping Model translations setup - database not ready"
    end
  end

  def self.fetch_all(options = {})
    if options[:site_scope]
      site_scope = options[:site_scope].to_i
      Model.joins(:site_scopes)
        .where("models_site_scopes.site_scope_id = ?", site_scope)
    else
      Model.all
    end
  end
end
