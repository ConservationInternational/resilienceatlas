require "shrine"
require "shrine/storage/file_system"

# Ensure upload directories exist
upload_root = Rails.env.test? ? "public" : "public"
upload_cache_path = File.join(Rails.root, upload_root, "uploads", "cache")
upload_store_path = File.join(Rails.root, upload_root, "uploads", "store")

FileUtils.mkdir_p(upload_cache_path) unless File.directory?(upload_cache_path)
FileUtils.mkdir_p(upload_store_path) unless File.directory?(upload_store_path)

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/cache"), # temporary
  store: Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/store") # permanent
}

Shrine.plugin :activerecord
Shrine.plugin :cached_attachment_data # for forms
