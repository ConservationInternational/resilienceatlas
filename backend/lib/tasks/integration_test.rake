# frozen_string_literal: true

namespace :integration_test do
  desc "Setup test data for integration tests"
  task setup_data: :environment do
    # Only run in test environment
    unless Rails.env.test?
      puts "This task should only be run in test environment"
      exit 1
    end

    puts "Setting up integration test data..."
    # Ensure models are loaded
    Rails.application.eager_load!

    # Clear existing data to ensure clean state
    [
      StaticPage::SectionReference,
      StaticPage::SectionItem,
      StaticPage::SectionParagraph,
      StaticPage::Section,
      StaticPage::Base,
      JourneyStep,
      Journey,
      Agrupation,
      Layer,
      LayerGroup,
      HomepageSection,
      Homepage,
      HomepageJourney,
      SitePage,
      SiteScope
    ].each do |model|
      model.destroy_all if model.respond_to?(:destroy_all)
    end

    # Create main site scope for Resilience Atlas (ID: 1 as expected by frontend)
    begin
      site_scope = FactoryBot.create(:site_scope,
        id: 1,
        name: "Resilience Atlas", # Match the spec expectation
        subdomain: "",
        header_theme: "Resilience",
        color: "#0089CC",
        password_protected: false)
      puts "✅ Created SiteScope with ID: #{site_scope.id}"
    rescue => e
      puts "❌ Failed to create SiteScope: #{e.message}"
      puts "Error details: #{e.backtrace.first(5).join("\n")}"
      raise e
    end

    # Create journeys with steps for the journey tests - following journeys_spec.rb pattern
    journeys = []
    3.times do |i|
      journey = FactoryBot.create(:journey,
        title: "Test Journey #{i + 1}",
        subtitle: "Test Journey Subtitle #{i + 1}",
        published: true, # Must be published to appear in API
        credits: "Conservation International",
        credits_url: "https://www.conservation.org")
      puts "✅ Created Journey with ID: #{journey.id}"

      # Create journey steps for the journey detail tests - following journeys_spec.rb pattern
      step_types = [
        {type: "landing", position: 1},
        {type: "chapter", position: 2, chapter_number: 2},
        {type: "embed", position: 3},
        {type: "conclusion", position: 4}
      ]

      step_types.each do |step_config|
        # Create more specific titles for different step types to ensure they render properly
        step_title = case step_config[:type]
        when "landing"
          "Welcome to Journey #{journey.title}"
        when "chapter"
          "Chapter #{step_config[:chapter_number]}: #{step_config[:type].capitalize} Content"
        when "embed"
          "Interactive #{step_config[:type].capitalize} Experience"
        when "conclusion"
          "Journey #{journey.title} Conclusion"
        else
          "#{step_config[:type].capitalize} Step"
        end

        step_attrs = {
          journey: journey,
          step_type: step_config[:type],
          title: step_title,
          subtitle: "Step subtitle for #{step_config[:type]}",
          description: "Description for #{step_config[:type]} step",
          content: "<p>Content for #{step_config[:type]} step</p>",
          position: step_config[:position],
          map_url: "/map"
        }
        step_attrs[:chapter_number] = step_config[:chapter_number] if step_config[:chapter_number]

        step = FactoryBot.create(:journey_step, step_attrs)
        puts "✅ Created JourneyStep #{step_config[:type]} with ID: #{step.id}, title: '#{step.title}'"
      end

      journeys << journey
    end

    # Create homepage journey and homepage - following homepages_spec.rb pattern
    begin
      homepage_journey = FactoryBot.create(:homepage_journey,
        title: "Integration Test Journey",
        position: 1)
      puts "✅ Created HomepageJourney with ID: #{homepage_journey.id}"
    rescue => e
      puts "❌ Failed to create HomepageJourney: #{e.message}"
      raise e
    end

    begin
      homepage = FactoryBot.create(:homepage,
        site_scope: site_scope,
        homepage_journey: homepage_journey,
        title: "Integration Test Homepage",
        subtitle: "Test subtitle for integration tests",
        credits: "Conservation International",
        credits_url: "https://www.conservation.org",
        show_journeys: true)
      puts "✅ Created Homepage with ID: #{homepage.id}"
    rescue => e
      puts "❌ Failed to create Homepage: #{e.message}"
      raise e
    end

    # Create homepage sections - following homepages_spec.rb pattern
    homepage_section = FactoryBot.create(:homepage_section,
      homepage: homepage,
      title: "Homepage Section",
      subtitle: "Homepage section subtitle",
      position: 1)
    puts "✅ Created HomepageSection with ID: #{homepage_section.id}"

    # Create site pages for the site endpoint - following sites_spec.rb pattern
    site_page = FactoryBot.create(:site_page,
      site_scope: site_scope,
      title: "Test Site Page",
      body: "Test site page content",
      priority: 1)
    puts "✅ Created SitePage with ID: #{site_page.id}"

    begin
      layer_group = FactoryBot.create(:layer_group,
        name: "Test Layer Group",
        order: 1,
        icon_class: "test-icon",
        category: "Analysis",
        site_scope: site_scope)
      puts "✅ Created LayerGroup with ID: #{layer_group.id}"
    rescue => e
      puts "❌ Failed to create LayerGroup: #{e.message}"
      raise e
    end

    # Create two specific layers with IDs that match the Cypress tests:
    # - Layer 66 is used in map.cy.js line 92 and line 167
    # - Layer 1429 is used in map.cy.js line 139 for "Livelihoods zones layer"
    begin
      layer_66 = FactoryBot.create(:layer,
        id: 66,
        name: "Test Layer 66",
        layer_type: "CartoDB",
        slug: "test-layer-66",
        zoom_max: 10,
        zoom_min: 1,
        dashboard_order: 1,
        layer_provider: "cartodb",
        interaction_config: "{}")
      puts "✅ Created Layer with ID: #{layer_66.id}"
    rescue => e
      puts "❌ Failed to create Layer 66: #{e.message}"
      raise e
    end

    begin
      layer_1429 = FactoryBot.create(:layer,
        id: 1429,
        name: "Livelihoods zones layer",
        layer_type: "CartoDB",
        slug: "livelihoods-zones-layer",
        zoom_max: 10,
        zoom_min: 1,
        dashboard_order: 2,
        layer_provider: "cartodb",
        interaction_config: "{}")
      puts "✅ Created Layer with ID: #{layer_1429.id}"
    rescue => e
      puts "❌ Failed to create Layer 1429: #{e.message}"
      raise e
    end

    # Create agrupations to link both layers to layer group
    begin
      agrupation_66 = FactoryBot.create(:agrupation,
        layer: layer_66,
        layer_group: layer_group,
        active: true)
      puts "✅ Created Agrupation for Layer 66 with ID: #{agrupation_66.id}"
    rescue => e
      puts "❌ Failed to create Agrupation for Layer 66: #{e.message}"
      raise e
    end

    begin
      agrupation_1429 = FactoryBot.create(:agrupation,
        layer: layer_1429,
        layer_group: layer_group,
        active: true)
      puts "✅ Created Agrupation for Layer 1429 with ID: #{agrupation_1429.id}"
    rescue => e
      puts "❌ Failed to create Agrupation for Layer 1429: #{e.message}"
      raise e
    end

    # Create About static page for /api/static_pages/about endpoint
    begin
      about_page = FactoryBot.create(:static_page,
        slug: "about",
        title: "About Integration Tests",
        image_credits: "Test Credits",
        image_credits_url: "https://example.com")
      puts "✅ Created About StaticPage with ID: #{about_page.id}"
    rescue => e
      puts "❌ Failed to create About StaticPage: #{e.message}"
      puts "Error details: #{e.backtrace.first(5).join("\n")}"
      raise e
    end

    # Create sections with proper relationships following the spec pattern
    # Create paragraph section with section_paragraph
    paragraph_section = FactoryBot.create(:static_page_section,
      static_page: about_page,
      slug: "content",
      title: "Content Section",
      title_size: 2,
      position: 1,
      show_at_navigation: true,
      section_type: "paragraph")
    puts "✅ Created Paragraph StaticPage Section with ID: #{paragraph_section.id}"

    section_paragraph = FactoryBot.create(:static_page_section_paragraph,
      section: paragraph_section,
      text: "<p>This is test content for the paragraph section.</p>",
      image_position: "left")
    puts "✅ Created StaticPage SectionParagraph with ID: #{section_paragraph.id}"

    # Create items section with section_items
    item_section = FactoryBot.create(:static_page_section,
      static_page: about_page,
      slug: "items",
      title: "Items Section",
      title_size: 2,
      position: 2,
      show_at_navigation: true,
      section_type: "items")
    puts "✅ Created Items StaticPage Section with ID: #{item_section.id}"

    # Create section items for the items section
    3.times do |i|
      item = FactoryBot.create(:static_page_section_item,
        section: item_section,
        title: "Test Item #{i + 1}",
        description: "<p>Description for test item #{i + 1}</p>",
        position: i + 1)
      puts "✅ Created StaticPage SectionItem with ID: #{item.id}"
    end

    # Create references section with section_references
    references_section = FactoryBot.create(:static_page_section,
      static_page: about_page,
      slug: "references",
      title: "References Section",
      title_size: 2,
      position: 3,
      show_at_navigation: true,
      section_type: "references")
    puts "✅ Created References StaticPage Section with ID: #{references_section.id}"

    # Create section references for the references section
    3.times do |i|
      reference = FactoryBot.create(:static_page_section_reference,
        section: references_section,
        slug: "reference-#{i + 1}",
        position: i + 1)
      puts "✅ Created StaticPage SectionReference with ID: #{reference.id}"
    end

    puts "\n📊 Integration test data summary:"
    puts "SiteScopes: #{SiteScope.count}"
    puts "LayerGroups: #{LayerGroup.count}"
    puts "Layers: #{Layer.count}"
    puts "Agrupations: #{Agrupation.count}"
    puts "Journeys: #{Journey.count}"
    puts "JourneySteps: #{JourneyStep.count}"
    puts "Homepages: #{Homepage.count}"
    puts "HomepageJourneys: #{HomepageJourney.count}"
    puts "StaticPages: #{StaticPage::Base.count}"
    puts "StaticPage Sections: #{StaticPage::Section.count}"
    puts "StaticPage SectionReferences: #{StaticPage::SectionReference.count}"
    puts "StaticPage SectionParagraphs: #{StaticPage::SectionParagraph.count}"
    puts "StaticPage SectionItems: #{StaticPage::SectionItem.count}"

    puts "\n✅ Integration test data setup complete!"
  end

  desc "Verify integration test data"
  task verify_data: :environment do
    puts "🔍 Verifying integration test data..."

    # Ensure models are loaded
    Rails.application.eager_load!

    # Check that expected data exists
    required_data = {
      "SiteScope with ID 1" => -> { SiteScope.find_by(id: 1) },
      "Homepage" => -> { Homepage.first },
      "About StaticPage" => -> { StaticPage::Base.find_by(slug: "about") },
      "LayerGroup" => -> { LayerGroup.first },
      "Layer" => -> { Layer.first },
      "Published Journey" => -> { Journey.where(published: true).first },
      "Journey Steps" => -> { JourneyStep.first }
    }

    all_good = true
    required_data.each do |name, check|
      result = check.call
      if result
        puts "✅ #{name} exists"
      else
        puts "❌ #{name} missing"
        all_good = false

        # Add debugging information for missing data
        case name
        when "SiteScope with ID 1"
          puts "  Debug: Total SiteScopes: #{SiteScope.count}"
          puts "  Debug: SiteScope IDs: #{SiteScope.pluck(:id).inspect}"
        when "Homepage"
          puts "  Debug: Total Homepages: #{Homepage.count}"
        when "About StaticPage"
          puts "  Debug: Total StaticPages: #{StaticPage::Base.count}"
          puts "  Debug: StaticPage slugs: #{StaticPage::Base.pluck(:slug).inspect}"
        when "LayerGroup"
          puts "  Debug: Total LayerGroups: #{LayerGroup.count}"
        when "Layer"
          puts "  Debug: Total Layers: #{Layer.count}"
        when "Published Journey"
          puts "  Debug: Total Journeys: #{Journey.count}"
          puts "  Debug: Published Journeys: #{Journey.where(published: true).count}"
        when "Journey Steps"
          puts "  Debug: Total JourneySteps: #{JourneyStep.count}"
        end
      end
    rescue => e
      puts "❌ Error checking #{name}: #{e.message}"
      all_good = false
    end

    if all_good
      puts "✅ All required integration test data is present"
    else
      puts "❌ Some required data is missing - run rake integration_test:setup_data"
      exit 1
    end
  end
end
 
 
