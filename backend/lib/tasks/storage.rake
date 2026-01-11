namespace :storage do
  desc "Extract journey images from the zip archive to public/storage"
  task extract_journey_images: :environment do
    require "zip"

    zip_path = Rails.root.join("db", "data", "journey_images.zip")
    destination = Rails.root.join("public", "storage")

    unless File.exist?(zip_path)
      puts "Journey images archive not found at #{zip_path}"
      puts "Skipping extraction."
      next
    end

    puts "Extracting journey images from #{zip_path} to #{destination}..."

    # Create destination directory if it doesn't exist
    FileUtils.mkdir_p(destination)

    extracted_count = 0
    skipped_count = 0

    Zip::File.open(zip_path) do |zip_file|
      zip_file.each do |entry|
        # Skip macOS metadata files
        next if entry.name.start_with?("__MACOSX")
        next if entry.name.include?("._")

        target_path = File.join(destination, entry.name)

        if entry.directory?
          FileUtils.mkdir_p(target_path)
        else
          # Skip if file already exists with same size
          if File.exist?(target_path) && File.size(target_path) == entry.size
            skipped_count += 1
            next
          end

          # Create parent directories
          FileUtils.mkdir_p(File.dirname(target_path))

          # Extract file
          entry.extract(target_path) { true } # true = overwrite
          extracted_count += 1
        end
      end
    end

    puts "Extraction complete: #{extracted_count} files extracted, #{skipped_count} files skipped (already present)"
  end

  desc "Copy homepage/static page seed images to public/storage with fixed keys"
  task setup_homepage_images: :environment do
    require_relative "../../db/data/homepage_images"

    puts "Setting up homepage seed images..."

    # Load the homepage images configuration
    HOMEPAGE_IMAGE_SOURCES.each do |key, source_relative_path|
      source_path = Rails.root.join(source_relative_path)

      unless File.exist?(source_path)
        puts "Warning: Source image not found: #{source_path}"
        next
      end

      # Determine the storage path using Active Storage's key-based directory structure
      # First 2 characters of key, then next 2 characters, then the full key as filename
      storage_dir = Rails.root.join("public", "storage", key[0, 2], key[2, 2])
      storage_path = File.join(storage_dir, key)

      if File.exist?(storage_path)
        puts "Image already exists: #{key}"
        next
      end

      FileUtils.mkdir_p(storage_dir)
      FileUtils.cp(source_path, storage_path)
      puts "Copied #{source_relative_path} -> #{storage_path}"
    end

    puts "Homepage seed images setup complete"
  end

  desc "Initialize storage with seed data (called during deployment)"
  task initialize: :environment do
    puts "Initializing storage directories..."

    # Ensure storage directories exist
    storage_dirs = [
      Rails.root.join("public", "storage"),
      Rails.root.join("storage"),
      Rails.root.join("public", "uploads")
    ]

    storage_dirs.each do |dir|
      unless Dir.exist?(dir)
        FileUtils.mkdir_p(dir)
        puts "Created #{dir}"
      end
    end

    # Extract journey images if the archive exists
    Rake::Task["storage:extract_journey_images"].invoke

    # Setup homepage images from app/assets
    Rake::Task["storage:setup_homepage_images"].invoke
  end
end
