# Configure ransackable attributes for Globalize translation models

Rails.application.config.after_initialize do
  # Only proceed if the database is available and migrations have been run
  begin
    if ActiveRecord::Base.connection.table_exists?('category_translations')
      Category.translation_class.class_eval do
        def self.ransackable_attributes(auth_object = nil)
          ["created_at", "id", "id_value", "locale", "category_id", "updated_at", "name", "description"]
        end
        
        def self.ransackable_associations(auth_object = nil)
          ["category"]
        end
      end if defined?(Category) && Category.respond_to?(:translation_class)
    end

    if ActiveRecord::Base.connection.table_exists?('layer_translations')
      Layer.translation_class.class_eval do
        def self.ransackable_attributes(auth_object = nil)
          ["analysis_text_template", "created_at", "data_units", "description", "id", "id_value", "info", "layer_id", "legend", "locale", "name", "processing", "title", "updated_at"]
        end
        
        def self.ransackable_associations(auth_object = nil)
          ["layer"]
        end
      end if defined?(Layer) && Layer.respond_to?(:translation_class)
    end

    if ActiveRecord::Base.connection.table_exists?('indicator_translations')
      Indicator.translation_class.class_eval do
        def self.ransackable_attributes(auth_object = nil)
          ["created_at", "id", "id_value", "locale", "indicator_id", "updated_at", "name"]
        end
        
        def self.ransackable_associations(auth_object = nil)
          ["indicator"]
        end
      end if defined?(Indicator) && Indicator.respond_to?(:translation_class)
    end

  rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
    Rails.logger&.info "Skipping ransack translation attributes setup - database not ready: #{e.message}"
  end
end
