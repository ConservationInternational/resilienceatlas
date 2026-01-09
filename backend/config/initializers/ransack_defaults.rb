# Ransack configuration to prevent security errors
# This sets up a more permissive default for development/test while staying secure

Ransack.configure do |config|
  # Ignore errors for missing ransackable_attributes in development/test
  # In production, models should explicitly define their ransackable attributes
  if Rails.env.development? || Rails.env.test?
    config.sanitize_custom_scope_booleans = false
    # Note: This doesn't disable the security check, but makes it more lenient
  end
end

# Default implementation for models that don't have explicit ransackable configuration
module RansackableDefaults
  extend ActiveSupport::Concern

  class_methods do
    def ransackable_attributes(auth_object = nil)
      # For models that inherit from this, return a sensible default
      # But prefer explicit configuration in each model
      if defined?(super)
        super
      else
        # Return basic timestamp columns that are generally safe to search
        %w[id created_at updated_at]
      end
    end

    def ransackable_associations(auth_object = nil)
      if defined?(super)
        super
      else
        []
      end
    end
  end
end
