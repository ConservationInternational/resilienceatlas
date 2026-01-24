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

          # Extract file content manually to avoid rubyzip path issues
          # entry.extract can have issues with destination paths in some versions
          File.open(target_path, "wb") do |file|
            file.write(entry.get_input_stream.read)
          end
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

    # Fix any existing blobs that are missing files
    Rake::Task["storage:fix_existing_blobs"].invoke
  end

  desc "Fix existing blobs by copying source images to match their keys"
  task fix_existing_blobs: :environment do
    puts "Fixing existing blobs with missing files..."

    # Map filenames to source paths - includes all known seed images
    filename_to_source = {
      # Homepage images
      "bg-welcome.jpg" => "app/assets/images/home/bg-welcome.jpg",
      "bg-explore.png" => "app/assets/images/home/bg-explore.png",
      "bg-about1.jpg" => "app/assets/images/home/bg-about1.jpg",
      "bg-about2.jpg" => "app/assets/images/home/bg-about2.jpg",
      # Thumbnail images
      "thumb-0.jpg" => "app/assets/images/home/thumb-0.jpg",
      "thumb-1.jpg" => "app/assets/images/home/thumb-1.jpg",
      "thumb-2.jpg" => "app/assets/images/home/thumb-2.jpg",
      "thumb-3.jpg" => "app/assets/images/home/thumb-3.jpg",
      "thumb-4.jpg" => "app/assets/images/home/thumb-4.jpg",
      "thumb-5.jpg" => "app/assets/images/home/thumb-5.jpg",
      "thumb-big-0.jpg" => "app/assets/images/home/thumb-0.jpg",
      "thumb-big-1.jpg" => "app/assets/images/home/thumb-1.jpg",
      "thumb-big-2.jpg" => "app/assets/images/home/thumb-2.jpg",
      "thumb-big-3.jpg" => "app/assets/images/home/thumb-3.jpg",
      "thumb-big-4.jpg" => "app/assets/images/home/thumb-4.jpg",
      "thumb-big-5.jpg" => "app/assets/images/home/thumb-5.jpg",
      # About page images
      "about-hero.jpg" => "app/assets/images/about-hero.jpg",
      "about-1.jpg" => "app/assets/images/about-1.jpg",
      "about-2.jpg" => "app/assets/images/about-2.jpg",
      # Team photos
      "alex_zvoleff.jpg" => "app/assets/images/team/alex_zvoleff.jpg",
      "kellee_koenig.jpg" => "app/assets/images/team/kellee_koenig.jpg",
      "monica_noon.jpg" => "app/assets/images/team/monica_noon.jpg",
      "raghav_shyla.jpg" => "app/assets/images/team/raghav_shyla.jpg",
      "sandy_andelman.jpg" => "app/assets/images/team/sandy_andelman.jpg",
      "sheila_brown.jpg" => "app/assets/images/team/sheila_brown.jpg",
      "tim_noviello.jpg" => "app/assets/images/team/tim_noviello.jpg",
      # Logo images (use existing SVG/PNG versions)
      "logo-vizzuality.png" => "app/assets/images/logo-vizzuality.svg",
      "logo-ci.png" => "app/assets/images/logo-ci.png",
      "logo-grp.png" => "app/assets/images/logo-grp.png",
      "logo-grp-white.png" => "app/assets/images/logo-grp-white.png",
      "grp-wordmark.png" => "app/assets/images/grp-wordmark.png",
      "cigrp-simply-logo.png" => "app/assets/images/cigrp-simply-logo.png"
    }

    fixed_count = 0
    skipped_count = 0
    missing_source_count = 0

    # Find all blobs with filenames we know about
    filename_to_source.each do |filename, source_relative_path|
      blobs = ActiveStorage::Blob.where(filename: filename)

      blobs.each do |blob|
        key = blob.key
        storage_dir = Rails.root.join("public", "storage", key[0, 2], key[2, 2])
        storage_path = File.join(storage_dir, key)

        # Skip if file already exists
        if File.exist?(storage_path)
          skipped_count += 1
          next
        end

        source_path = Rails.root.join(source_relative_path)
        unless File.exist?(source_path)
          puts "Warning: Source image not found for #{filename}: #{source_path}"
          missing_source_count += 1
          next
        end

        # Create directory and copy file
        FileUtils.mkdir_p(storage_dir)
        FileUtils.cp(source_path, storage_path)

        # Update blob metadata to match actual file
        file_content = File.binread(source_path)
        blob.update!(
          byte_size: file_content.bytesize,
          checksum: Digest::MD5.base64digest(file_content)
        )

        puts "Fixed blob #{blob.id}: #{filename} -> #{storage_path}"
        fixed_count += 1
      end
    end

    puts "Blob fix complete: #{fixed_count} fixed, #{skipped_count} already present, #{missing_source_count} missing source"
  end
end
