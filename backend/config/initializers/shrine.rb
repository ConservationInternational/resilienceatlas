require "shrine"
require "shrine/storage/file_system"

if Rails.env.production? || Rails.env.staging?
  # -----------------------------------------------------------------------
  # S3-backed storage for production / staging
  # -----------------------------------------------------------------------
  require "shrine/storage/s3"

  s3_options = {
    bucket: ENV.fetch("S3_BUCKET", "resilienceatlas"),
    region: ENV.fetch("AWS_REGION", "us-east-1"),
    access_key_id: ENV["AWS_ACCESS_KEY_ID"],
    secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
  }

  Shrine.storages = {
    # Temporary: presigned uploads land here first
    cache: Shrine::Storage::S3.new(prefix: "uploads/cache", **s3_options),
    # Permanent processed files
    store: Shrine::Storage::S3.new(prefix: "uploads/store", **s3_options),
    # Staging area for vector/CSV imports before background processing
    staging: Shrine::Storage::S3.new(prefix: ENV.fetch("S3_STAGING_PREFIX", "staging"), **s3_options),
    # COG rasters
    cogs: Shrine::Storage::S3.new(prefix: ENV.fetch("COG_PREFIX", "cogs"), **s3_options)
  }
else
  # -----------------------------------------------------------------------
  # Filesystem storage for development / test
  # -----------------------------------------------------------------------
  upload_root = "public"
  upload_cache_path = File.join(Rails.root, upload_root, "uploads", "cache")
  upload_store_path = File.join(Rails.root, upload_root, "uploads", "store")
  upload_staging_path = File.join(Rails.root, upload_root, "uploads", "staging")

  [upload_cache_path, upload_store_path, upload_staging_path].each do |path|
    begin
      FileUtils.mkdir_p(path) unless File.directory?(path)
    rescue Errno::EACCES => e
      Rails.logger.warn "Unable to create upload directory #{path}: #{e.message}"
    rescue => e
      Rails.logger.error "Error creating upload directory #{path}: #{e.message}"
      raise e unless Rails.env.test?
    end
  end

  Shrine.storages = {
    cache:   Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/cache"),
    store:   Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/store"),
    staging: Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/staging"),
    cogs:    Shrine::Storage::FileSystem.new(upload_root, prefix: "uploads/cogs")
  }
end

Shrine.plugin :activerecord
Shrine.plugin :cached_attachment_data # for forms

# Presigned URL generation (used by the uploads controller for direct S3 multipart)
Shrine.plugin :presign_endpoint, presign_options: {
  method: :put,
  expires_in: 3600 # 1 hour
}
Shrine.plugin :determine_mime_type
