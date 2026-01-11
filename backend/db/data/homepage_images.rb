# Homepage and Static Page seed images with fixed blob keys
# These records match the files in homepage_images.zip

# Homepage background images and sections
HOMEPAGE_BLOBS = [
  {id: 100, key: "seedhomebgwelcome0001", filename: "bg-welcome.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 278635, checksum: "homepagewelcome001==", service_name: "local_public"},
  {id: 101, key: "seedhomebgexplore0002", filename: "bg-explore.png", content_type: "image/png", metadata: {"identified" => true, "analyzed" => true}, byte_size: 150000, checksum: "homepageexplore002==", service_name: "local_public"},
  {id: 102, key: "seedhomebgabout10003", filename: "bg-about1.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 200000, checksum: "homepageabout1003==", service_name: "local_public"},
  {id: 103, key: "seedhomebgabout20004", filename: "bg-about2.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 200000, checksum: "homepageabout2004==", service_name: "local_public"},
  {id: 104, key: "seedhomethumb00005", filename: "thumb-0.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 50000, checksum: "homepagethumb0005==", service_name: "local_public"},
  {id: 105, key: "seedhomethumb10006", filename: "thumb-1.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 50000, checksum: "homepagethumb1006==", service_name: "local_public"},
  {id: 106, key: "seedhomethumb20007", filename: "thumb-2.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 50000, checksum: "homepagethumb2007==", service_name: "local_public"},
  {id: 107, key: "seedhomethumb30008", filename: "thumb-3.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 50000, checksum: "homepagethumb3008==", service_name: "local_public"},
  {id: 108, key: "seedhomethumb40009", filename: "thumb-4.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 50000, checksum: "homepagethumb4009==", service_name: "local_public"},
  {id: 109, key: "seedhomethumb50010", filename: "thumb-5.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 50000, checksum: "homepagethumb5010==", service_name: "local_public"},
  {id: 110, key: "seedabouthero000011", filename: "about-hero.jpg", content_type: "image/jpeg", metadata: {"identified" => true, "analyzed" => true}, byte_size: 150000, checksum: "staticabouthero011==", service_name: "local_public"}
]

# Source image paths for each blob key
HOMEPAGE_IMAGE_SOURCES = {
  "seedhomebgwelcome0001" => "app/assets/images/home/bg-welcome.jpg",
  "seedhomebgexplore0002" => "app/assets/images/home/bg-explore.png",
  "seedhomebgabout10003" => "app/assets/images/home/bg-about1.jpg",
  "seedhomebgabout20004" => "app/assets/images/home/bg-about2.jpg",
  "seedhomethumb00005" => "app/assets/images/home/thumb-0.jpg",
  "seedhomethumb10006" => "app/assets/images/home/thumb-1.jpg",
  "seedhomethumb20007" => "app/assets/images/home/thumb-2.jpg",
  "seedhomethumb30008" => "app/assets/images/home/thumb-3.jpg",
  "seedhomethumb40009" => "app/assets/images/home/thumb-4.jpg",
  "seedhomethumb50010" => "app/assets/images/home/thumb-5.jpg",
  "seedabouthero000011" => "app/assets/images/about-hero.jpg"
}

def create_homepage_seed_blobs!
  puts "Creating homepage seed blobs..."

  HOMEPAGE_BLOBS.each do |blob_attrs|
    source_path = Rails.root.join(HOMEPAGE_IMAGE_SOURCES[blob_attrs[:key]])

    unless File.exist?(source_path)
      puts "Warning: Source image not found: #{source_path}"
      next
    end

    # Update blob with actual file metadata
    file_content = File.binread(source_path)
    blob_attrs[:byte_size] = file_content.bytesize
    blob_attrs[:checksum] = Digest::MD5.base64digest(file_content)

    # Create or update the blob record
    blob = ActiveStorage::Blob.find_or_initialize_by(key: blob_attrs[:key])
    blob.assign_attributes(blob_attrs.except(:id))
    blob.id = blob_attrs[:id] if blob.new_record?
    blob.save!

    # Copy file to Active Storage location
    storage_path = Rails.root.join("public", "storage", blob_attrs[:key][0, 2], blob_attrs[:key][2, 2])
    FileUtils.mkdir_p(storage_path)
    FileUtils.cp(source_path, File.join(storage_path, blob_attrs[:key]))

    puts "Created blob for #{blob_attrs[:filename]} with key #{blob_attrs[:key]}"
  end

  # Reset sequence
  ActiveRecord::Base.connection.execute(
    "SELECT setval('active_storage_blobs_id_seq', COALESCE((SELECT MAX(id) FROM active_storage_blobs), 1))"
  )

  puts "Homepage seed blobs created: #{HOMEPAGE_BLOBS.count}"
end

def attach_homepage_seed_images!(homepage, about_page = nil)
  # Attach homepage background image
  if homepage && !homepage.background_image.attached?
    blob = ActiveStorage::Blob.find_by(key: "seedhomebgwelcome0001")
    if blob
      homepage.background_image.attach(blob)
      puts "Attached background image to homepage"
    end
  end

  # Attach about page image
  if about_page && !about_page.image.attached?
    blob = ActiveStorage::Blob.find_by(key: "seedabouthero000011")
    if blob
      about_page.image.attach(blob)
      puts "Attached image to about page"
    end
  end
end
