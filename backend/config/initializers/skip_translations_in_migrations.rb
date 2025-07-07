# Skip translations during migrations to prevent table access errors
# This prevents models with `translates` from trying to access non-existent tables
# during migrations

if Rails.env.test? && defined?(Rails::Console).nil?
  # Check if we're running migrations or setup
  if ARGV.any? { |arg| arg.include?('db:') || arg.include?('test:') }
    # Temporarily disable Globalize translations during migrations
    begin
      require 'globalize'
      
      # Override the translates method to be a no-op during migrations
      Module.class_eval do
        alias_method :original_translates, :translates if method_defined?(:translates)
        
        def translates(*args)
          # Only skip if we're in a migration context
          return if defined?(ActiveRecord::Migration) && 
                   (caller.any? { |line| line.include?('migrate') } ||
                    !ActiveRecord::Base.connection.table_exists?('homepage_translations'))
          
          original_translates(*args) if respond_to?(:original_translates)
        end
      end
      
      # Also handle active_admin_translates
      if defined?(ActiveAdmin)
        Module.class_eval do
          alias_method :original_active_admin_translates, :active_admin_translates if method_defined?(:active_admin_translates)
          
          def active_admin_translates(*args)
            # Only skip if tables don't exist
            return unless ActiveRecord::Base.connection.table_exists?('homepage_translations')
            
            original_active_admin_translates(*args) if respond_to?(:original_active_admin_translates)
          end
        end
      end
      
    rescue LoadError, NameError
      # Globalize not available, skip
    end
  end
end
