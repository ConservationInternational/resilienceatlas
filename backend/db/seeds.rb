# Only create seed data in development/production, not in test environment
unless Rails.env.test?
  unless AdminUser.exists?(email: "admin@example.com")
    AdminUser.create!(email: "admin@example.com", password: "password", password_confirmation: "password")
  end
  if SiteScope.all.size == 0
    SiteScope.create!(name: "Resilience Atlas", id: 1, header_theme: "Resilience", color: "#0089CC")
  end

  # Create password-protected site scope for testing
  unless SiteScope.exists?(id: 2)
    protected_scope = SiteScope.new(
      id: 2,
      name: "Protected scope",
      subdomain: "protected",
      header_theme: "ci-theme",
      color: "#0089CC",
      password_protected: true,
      username: "user"
    )
    protected_scope.password = "password"
    protected_scope.save!
    puts "Created password-protected site scope (username: user, password: password)"
  end

  # Create homepage for Resilience Atlas site scope if it doesn't exist
  resilience_atlas_site_scope = SiteScope.find_by(id: 1)
  if resilience_atlas_site_scope && !Homepage.exists?(site_scope_id: resilience_atlas_site_scope.id)
    begin
      # Create a homepage journey first
      homepage_journey = HomepageJourney.create!(
        title: "Welcome to Resilience Atlas",
        position: 1
      )

      # Path to the background image
      image_path = Rails.root.join("app", "assets", "images", "home", "bg-welcome.jpg")

      # Create homepage with proper Active Storage attachment
      homepage = Homepage.new(
        site_scope_id: resilience_atlas_site_scope.id,
        homepage_journey_id: homepage_journey.id,
        title: "Resilience Atlas",
        subtitle: "Building resilience to climate change and development challenges",
        credits: "Conservation International",
        credits_url: "https://www.conservation.org",
        show_journeys: true
      )

      # Save without validation first to get a persisted record
      homepage.save!(validate: false)

      # Now attach the image to the persisted record
      homepage.background_image.attach(
        io: File.open(image_path),
        filename: "bg-welcome.jpg",
        content_type: "image/jpeg"
      )

      # Validate the record now that the image is attached
      homepage.valid? # This will populate errors if validation fails
      if homepage.errors.any?
        puts "Homepage validation errors: #{homepage.errors.full_messages}"
      else
        puts "Created homepage and homepage journey for Resilience Atlas site scope with background image"
      end
    rescue => e
      puts "Error creating homepage: #{e.message}"
      puts "Image path attempted: #{Rails.root.join("app", "assets", "images", "home", "bg-welcome.jpg")}"
      puts "Image exists: #{File.exist?(Rails.root.join("app", "assets", "images", "home", "bg-welcome.jpg"))}"
      puts e.backtrace.first(5) if e.backtrace
    end
  end

  # Create about static page if it doesn't exist
  unless StaticPage::Base.exists?(slug: "about")
    puts "Creating about static page..."

    # Path to an image for the about page
    about_image_path = Rails.root.join("app", "assets", "images", "about-hero.jpg")

    about_page = StaticPage::Base.new(
      slug: "about",
      title: "About Resilience Atlas"
    )

    # Save without validation first to get a persisted record
    about_page.save!(validate: false)

    # Attach the image to the persisted record
    about_page.image.attach(
      io: File.open(about_image_path),
      filename: "about-hero.jpg",
      content_type: "image/jpeg"
    )

    # Validate the record now that the image is attached
    about_page.valid? # This will populate errors if validation fails
    if about_page.errors.any?
      puts "About page validation errors: #{about_page.errors.full_messages}"
    else
      # Create a basic section
      section = StaticPage::Section.create!(
        static_page: about_page,
        section_type: :paragraph,
        title: "About",
        position: 1
      )

      # Create a paragraph for the section
      StaticPage::SectionParagraph.create!(
        section: section,
        text: "Welcome to the Resilience Atlas. This platform provides data and insights for building resilience to climate change and development challenges.",
        image_position: "right"
      )

      puts "Created about static page successfully"
    end
  end

  # Import layers from layers.rb if no layers exist
  if Layer.count == 0
    puts "No layers found, importing from layers.rb..."
    layers_file = Rails.root.join("db", "data", "layers.rb")
    if File.exist?(layers_file)
      # Import layers directly - layers.rb should have all required fields
      # But skip creating records that already exist
      existing_site_scope_ids = SiteScope.pluck(:id)
      existing_layer_group_ids = LayerGroup.pluck(:id)
      existing_agrupation_ids = Agrupation.pluck(:id)

      puts "Existing site_scope IDs: #{existing_site_scope_ids}"
      puts "Existing layer_group IDs: #{existing_layer_group_ids}"
      puts "Existing agrupation IDs: #{existing_agrupation_ids}"

      # Read the file content and modify it to skip existing records
      content = File.read(layers_file)

      # Skip SiteScope creation if any exist
      if existing_site_scope_ids.any?
        puts "Skipping SiteScope creation - site_scopes already exist"
        content = content.gsub(/SiteScope\.create!\(\[.*?\]\)/m, "# SiteScope creation skipped - already exists")
      end

      # Skip LayerGroup creation if any exist
      if existing_layer_group_ids.any?
        puts "Skipping LayerGroup creation - layer_groups already exist"
        content = content.gsub(/LayerGroup\.create!\(\[.*?\]\)/m, "# LayerGroup creation skipped - already exists")
      end

      # Skip Agrupation creation if any exist
      if existing_agrupation_ids.any?
        puts "Skipping Agrupation creation - agrupations already exist"
        content = content.gsub(/Agrupation\.create!\(\[.*?\]\)/m, "# Agrupation creation skipped - already exists")
      end

      # Execute the modified content
      eval(content, binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
      puts "Layers imported successfully from layers.rb"
    else
      puts "Warning: layers.rb file not found at #{layers_file}"
    end
  else
    puts "Layers already exist (#{Layer.count} layers, #{LayerGroup.count} layer groups)"
  end

  # Import journeys from journeys.rb if no journeys exist
  if Journey.count == 0
    puts "No journeys found, importing from journeys.rb..."
    journeys_file = Rails.root.join("db", "data", "journeys.rb")
    if File.exist?(journeys_file)
      # Import journeys with custom handling for the at_least_one_step validation
      begin
        # Temporarily disable the at_least_one_step callback
        Journey.skip_callback(:save, :after, :at_least_one_step)

        content = File.read(journeys_file)

        # Extract and execute just the Journey.create! part first
        journey_section = content.match(/Journey\.create!\(\[(.*?)\]\)/m)
        if journey_section
          eval("Journey.create!([#{journey_section[1]}])", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
          puts "Journeys created: #{Journey.count}"

          # Update sequence to prevent ID conflicts
          ActiveRecord::Base.connection.execute("SELECT setval('journeys_id_seq', (SELECT MAX(id) FROM journeys))")

          # Extract and execute the JourneyStep.create! part
          journey_step_section = content.match(/JourneyStep\.create!\(\[(.*?)\]\)/m)
          if journey_step_section
            eval("JourneyStep.create!([#{journey_step_section[1]}])", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
            puts "Journey steps created: #{JourneyStep.count}"

            # Update journey step sequence as well
            ActiveRecord::Base.connection.execute("SELECT setval('journey_steps_id_seq', (SELECT MAX(id) FROM journey_steps))")
          end

          # Extract and execute the ActiveStorage::Blob.create! part
          blob_section = content.match(/ActiveStorage::Blob\.create!\(\[(.*?)\]\)/m)
          if blob_section
            eval("ActiveStorage::Blob.create!([#{blob_section[1]}])", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
            puts "Active Storage blobs created: #{ActiveStorage::Blob.count}"

            # Update blob sequence as well
            ActiveRecord::Base.connection.execute("SELECT setval('active_storage_blobs_id_seq', (SELECT MAX(id) FROM active_storage_blobs))")
          end

          # Extract and execute the ActiveStorage::Attachment.create! part
          attachment_section = content.match(/ActiveStorage::Attachment\.create!\(\[(.*?)\]\)/m)
          if attachment_section
            eval("ActiveStorage::Attachment.create!([#{attachment_section[1]}])", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
            puts "Active Storage attachments created: #{ActiveStorage::Attachment.count}"

            # Update attachment sequence as well
            ActiveRecord::Base.connection.execute("SELECT setval('active_storage_attachments_id_seq', (SELECT MAX(id) FROM active_storage_attachments))")
          end
        end

        # Re-enable the callback
        Journey.set_callback(:save, :after, :at_least_one_step)

        # Now attach background images to the journeys
        puts "Attaching background images to journeys..."
        journey_image_mapping = {
          4 => "journey1bg0.jpg",  # Ethiopia Smallholder Maize
          5 => "journey2bg0.jpg",  # Ethiopia Pastoral Livelihoods
          6 => "journey3bg0.jpg",  # India Cotton production
          7 => "journey4bg0.jpg",  # Africa Coffee production
          8 => "journey5bg0.jpg"   # Madagascar Ecosystem-based adaptation
        }

        journey_image_mapping.each do |journey_id, image_filename|
          journey = Journey.find_by(id: journey_id)
          if journey
            image_path = Rails.root.join("app", "assets", "images", "journeys", image_filename)
            if File.exist?(image_path)
              begin
                journey.background_image.attach(
                  io: File.open(image_path),
                  filename: image_filename,
                  content_type: "image/jpeg"
                )

                # Validate the record now that the image is attached
                if journey.valid?
                  puts "  ✓ Attached #{image_filename} to Journey #{journey_id} (#{journey.title})"
                else
                  puts "  ⚠ Attached #{image_filename} to Journey #{journey_id} but validation failed: #{journey.errors.full_messages.join(", ")}"
                end
              rescue => e
                puts "  ✗ Error attaching image to Journey #{journey_id}: #{e.message}"
              end
            else
              puts "  ⚠ Warning: Image file not found: #{image_path}"
            end
          else
            puts "  ⚠ Warning: Journey #{journey_id} not found"
          end
        end

        puts "Journeys imported successfully from journeys.rb (#{Journey.count} journeys, #{JourneyStep.count} journey steps)"
      rescue => e
        # Re-enable the callback even if there's an error
        Journey.set_callback(:save, :after, :at_least_one_step)
        puts "Journey import failed: #{e.message}"
        puts "Trying direct load method..."

        # Fall back to direct load if the above fails
        load(journeys_file)
      end
    else
      puts "Warning: journeys.rb file not found at #{journeys_file}"
    end
  else
    puts "Journeys already exist (#{Journey.count} journeys, #{JourneyStep.count} journey steps)"

    # Check if journeys need background images attached
    journeys_without_images = Journey.where.missing(:background_image_attachment)
    if journeys_without_images.any?
      puts "Found #{journeys_without_images.count} journeys without background images, attaching them..."
      journey_image_mapping = {
        4 => "journey1bg0.jpg",  # Ethiopia Smallholder Maize
        5 => "journey2bg0.jpg",  # Ethiopia Pastoral Livelihoods
        6 => "journey3bg0.jpg",  # India Cotton production
        7 => "journey4bg0.jpg",  # Africa Coffee production
        8 => "journey5bg0.jpg"   # Madagascar Ecosystem-based adaptation
      }

      journeys_without_images.each do |journey|
        image_filename = journey_image_mapping[journey.id]
        if image_filename
          image_path = Rails.root.join("app", "assets", "images", "journeys", image_filename)
          if File.exist?(image_path)
            begin
              journey.background_image.attach(
                io: File.open(image_path),
                filename: image_filename,
                content_type: "image/jpeg"
              )

              if journey.valid?
                puts "  ✓ Attached #{image_filename} to existing Journey #{journey.id} (#{journey.title})"
              else
                puts "  ⚠ Attached #{image_filename} to existing Journey #{journey.id} but validation failed: #{journey.errors.full_messages.join(", ")}"
              end
            rescue => e
              puts "  ✗ Error attaching image to existing Journey #{journey.id}: #{e.message}"
            end
          end
        end
      end
    end

    # Check if journey steps need background images attached
    journey_steps_without_images = JourneyStep.where(step_type: %w[landing conclusion chapter]).where.missing(:background_image_attachment)
    if journey_steps_without_images.any?
      puts "Found #{journey_steps_without_images.count} journey steps without background images, loading from journeys.rb..."
      journeys_file = Rails.root.join("db", "data", "journeys.rb")
      if File.exist?(journeys_file)
        content = File.read(journeys_file)

        # Check if there are missing blobs and create them
        blob_section = content.match(/ActiveStorage::Blob\.create!\(\[(.*?)\]\)\s*\nActiveStorage::Attachment/m)
        if blob_section
          begin
            # Count blobs before
            blobs_before = ActiveStorage::Blob.count

            # Create missing blobs using the extracted data
            blob_array_str = blob_section[1]
            # Use a safer eval approach - wrap in a lambda to evaluate
            blobs_data = eval("[#{blob_array_str}]", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
            blobs_data.each do |blob_attrs|
              unless ActiveStorage::Blob.exists?(id: blob_attrs[:id])
                ActiveStorage::Blob.create!(blob_attrs)
              end
            end

            ActiveRecord::Base.connection.execute("SELECT setval('active_storage_blobs_id_seq', (SELECT COALESCE(MAX(id), 1) FROM active_storage_blobs))")
            blobs_created = ActiveStorage::Blob.count - blobs_before
            puts "  Created #{blobs_created} Active Storage blobs (#{ActiveStorage::Blob.count} total)"
          rescue => e
            puts "  ⚠ Error creating blobs: #{e.message}"
          end
        end

        # Check if there are missing attachments and create them
        attachment_section = content.match(/ActiveStorage::Attachment\.create!\(\[(.*?)\]\)/m)
        if attachment_section
          begin
            # Count attachments before
            attachments_before = ActiveStorage::Attachment.count

            # Create missing attachments
            attachment_array_str = attachment_section[1]
            attachments_data = eval("[#{attachment_array_str}]", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
            attachments_data.each do |attachment_attrs|
              record_type = attachment_attrs[:record_type]
              record_id = attachment_attrs[:record_id]
              name = attachment_attrs[:name]
              # Only create if not already exists and the blob exists
              if ActiveStorage::Blob.exists?(id: attachment_attrs[:blob_id]) &&
                  !ActiveStorage::Attachment.exists?(record_type: record_type, record_id: record_id, name: name)
                ActiveStorage::Attachment.create!(attachment_attrs)
              end
            end

            ActiveRecord::Base.connection.execute("SELECT setval('active_storage_attachments_id_seq', (SELECT COALESCE(MAX(id), 1) FROM active_storage_attachments))")
            attachments_created = ActiveStorage::Attachment.count - attachments_before
            puts "  Created #{attachments_created} Active Storage attachments (#{ActiveStorage::Attachment.count} total)"
          rescue => e
            puts "  ⚠ Error creating attachments: #{e.message}"
          end
        end

        # Re-check and report
        remaining_without_images = JourneyStep.where(step_type: %w[landing conclusion chapter]).where.missing(:background_image_attachment).count
        if remaining_without_images == 0
          puts "  ✓ All journey steps now have background images"
        else
          puts "  ⚠ #{remaining_without_images} journey steps still without background images"
        end
      end
    end
  end

  # Import map menu entries if none exist
  if MapMenuEntry.count == 0
    puts "No map menu entries found, creating navigation structure..."

    gef = MapMenuEntry.create! label: "GEF-funded Projects", position: 1
    country = MapMenuEntry.create! label: "Country Atlases", position: 2
    vital = MapMenuEntry.create! label: "Vital Signs", position: 3
    regions = MapMenuEntry.create! label: "Regions", position: 4
    _themes = MapMenuEntry.create! label: "Themes", position: 5

    MapMenuEntry.create! label: "Trends.Earth",
      link: "https://maps.trends.earth/map",
      position: 1, parent: gef
    MapMenuEntry.create! label: "GEF-IAP-Food Security",
      link: "https://foodsecurityiap.resilienceatlas.org/map",
      position: 2, parent: gef

    MapMenuEntry.create! label: "Madagascar",
      link: "https://madagascar.resilienceatlas.org/map",
      position: 1, parent: country
    MapMenuEntry.create! label: "South Africa",
      link: "https://southafrica.resilienceatlas.org/map",
      position: 2, parent: country
    MapMenuEntry.create! label: "Indonesia",
      link: "https://indonesia.resilienceatlas.org/map",
      position: 3, parent: country
    MapMenuEntry.create! label: "Ethiopia",
      link: "https://ethiopia.resilienceatlas.org/map",
      position: 4, parent: country
    MapMenuEntry.create! label: "Democratic Republic of Congo",
      link: "https://drc.resilienceatlas.org/map",
      position: 5, parent: country

    MapMenuEntry.create! label: "Ghana",
      link: "http://ghana.vitalsigns.org/explore-atlas-ghana",
      position: 1, parent: vital
    MapMenuEntry.create! label: "Rwanda",
      link: "http://rwanda.vitalsigns.org/explore-atlas-rwanda",
      position: 2, parent: vital
    MapMenuEntry.create! label: "Tanzania",
      link: "http://tanzania.vitalsigns.org/explore-atlas-tanzania",
      position: 3, parent: vital
    MapMenuEntry.create! label: "Uganda",
      link: "http://uganda.vitalsigns.org/explore-atlas-uganda",
      position: 4, parent: vital
    MapMenuEntry.create! label: "Indicators",
      link: "https://indicators.resilienceatlas.org/map",
      position: 5, parent: vital
    MapMenuEntry.create! label: "DSSG",
      link: "https://dssg.resilienceatlas.org/map",
      position: 6, parent: vital

    MapMenuEntry.create! label: "Africa",
      link: "https://africa.resilienceatlas.org/map",
      position: 1, parent: regions
    MapMenuEntry.create! label: "Asia",
      link: "https://asia.resilienceatlas.org/map",
      position: 2, parent: regions
    MapMenuEntry.create! label: "Amazonia",
      link: "https://amazonia.resilienceatlas.org/map",
      position: 3, parent: regions

    MapMenuEntry.create! label: "Prioritization",
      link: "https://prioritization.resilienceatlas.org/map",
      position: 1, parent: regions
    MapMenuEntry.create! label: "Intensification",
      link: "https://intensification.resilienceatlas.org/map",
      position: 2, parent: regions

    puts "Map menu entries created: #{MapMenuEntry.count}"
  else
    puts "Map menu entries already exist (#{MapMenuEntry.count} entries)"
  end

  # Reset PostgreSQL sequences for tables that were seeded with explicit IDs
  # This prevents "duplicate key value violates unique constraint" errors
  puts "Resetting PostgreSQL sequences..."
  %w[site_scopes].each do |table_name|
    ActiveRecord::Base.connection.execute(
      "SELECT setval('#{table_name}_id_seq', COALESCE((SELECT MAX(id) FROM #{table_name}), 1))"
    )
  end
  puts "PostgreSQL sequences reset successfully"
end
