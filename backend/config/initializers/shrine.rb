require "shrine"
require "shrine/storage/file_system"

# Ensure upload directories exist with proper error handling
upload_root = "public"
upload_cache_path = File.join(Rails.root, upload_root, "uploads", "cache")
upload_store_path = File.join(Rails.root, upload_root, "uploads", "store")

begin
  FileUtils.mkdir_p(upload_cache_path) unless File.directory?(upload_cache_path)
  FileUtils.mkdir_p(upload_store_path) unless File.directory?(upload_store_path)
rescue Errno::EACCES => e
  Rails.logger.warn "Unable to create upload directories: #{e.message}. Directories may need to be created manually."
  # Continue initialization as directories might already exist or be created by external process
rescue => e
  Rails.logger.error "Error creating upload directories: #{e.message}"
  raise e unless Rails.env.test? # In test env, continue even if directory creation fails
end

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/cache"), # temporary
  store: Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/store") # permanent
}

Shrine.plugin :activerecord
Shrine.plugin :cached_attachment_data # for forms
