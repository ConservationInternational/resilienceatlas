# Fix for Rails 7.2+ frozen autoload paths issue in Docker environments
# This addresses the FrozenError that occurs when gems try to modify autoload_paths

Rails.application.config.before_initialize do
  # Store original autoload paths before they get frozen
  Rails.application.config.autoload_paths.dup

  # Monkey patch Rails::Engine to prevent frozen array modification
  Rails::Engine.class_eval do
    def self.inherited(base)
      unless base == Rails::Application
        Rails::Railtie.inherited(base)

        # Ensure autoload_paths is mutable when gems try to modify it
        if Rails.application.config.autoload_paths.frozen?
          Rails.application.config.autoload_paths = original_autoload_paths.dup
        end
      end
    end
  end

  # Override the autoload_paths setter to always return a mutable array
  Rails.application.config.class.class_eval do
    alias_method :original_autoload_paths=, :autoload_paths=

    def autoload_paths=(paths)
      (paths.is_a?(Array) ? paths.dup : paths)
    end
  end
end

# Additional safety net for test environment
if Rails.env.test?
  Rails.application.config.after_initialize do
    # Ensure autoload_paths remains mutable throughout the application lifecycle
    Rails.application.config.autoload_paths = Rails.application.config.autoload_paths.dup unless Rails.application.config.autoload_paths.frozen?
  end
end
