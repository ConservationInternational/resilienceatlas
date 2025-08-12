unless AdminUser.exists?(email: "admin@cigrm.com")
  AdminUser.create!(email: "admin@cigrm.com", password: "c1grm.pass", password_confirmation: "c1grm.pass")
end
if SiteScope.all.size == 0
  SiteScope.create!(name: "CIGRP", id: 1, header_theme: "Resilience")
  SiteScope.create!(name: "VS Indicators", id: 2, header_theme: "Indicators")
  SiteScope.create!(name: "VS Tanzania", id: 3, header_theme: "Tanzania")
  SiteScope.create!(name: "VS Ghana", id: 4, header_theme: "Ghana")
  SiteScope.create!(name: "VS Uganda", id: 5, header_theme: "Uganda")
  SiteScope.create!(name: "VS Rwanda", id: 6, header_theme: "Rwanda")
end

# Create homepage for CIGRP site scope if it doesn't exist
cigrp_site_scope = SiteScope.find_by(id: 1)
if cigrp_site_scope && !Homepage.exists?(site_scope_id: cigrp_site_scope.id)
  begin
    # Path to the background image
    image_path = Rails.root.join("app", "assets", "images", "home", "bg-welcome.jpg")
    
    if File.exist?(image_path)
      # Create a homepage journey first
      homepage_journey = HomepageJourney.create!(
        title: "Welcome to Resilience Atlas",
        position: 1
      )
      
      homepage = Homepage.new(
        site_scope_id: cigrp_site_scope.id,
        homepage_journey_id: homepage_journey.id,
        title: "Resilience Atlas",
        subtitle: "Building resilience to climate change and development challenges",
        credits: "Conservation International",
        credits_url: "https://www.conservation.org",
        show_journeys: true
      )
      
      # Attach the background image
      homepage.background_image.attach(
        io: File.open(image_path),
        filename: "bg-welcome.jpg",
        content_type: "image/jpeg"
      )
      
      homepage.save!
      puts "Created homepage and homepage journey for CIGRP site scope"
    else
      puts "Background image not found at #{image_path}, skipping homepage creation"
    end
  rescue => e
    puts "Error creating homepage: #{e.message}"
  end
end
