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
      Homepage,
      HomepageJourney,
      SiteScope
    ].each do |model|
      model.delete_all if model.respond_to?(:delete_all)
    end

    # Create main site scope for Resilience Atlas (ID: 1 as expected by frontend)
    site_scope = FactoryBot.create(:site_scope,
      id: 1,
      name: "Resilience Atlas", # Match the spec expectation
      subdomain: "test",
      header_theme: "Resilience",
      color: "#0089CC",
      password_protected: false
    )
    puts "✅ Created SiteScope with ID: #{site_scope.id}"

    # Create journeys with steps for the journey tests - following journeys_spec.rb pattern
    journeys = []
    3.times do |i|
      journey = FactoryBot.create(:journey,
        title: "Test Journey #{i+1}",
        subtitle: "Test Journey Subtitle #{i+1}",
        published: true, # Must be published to appear in API
        credits: "Conservation International",
        credits_url: "https://www.conservation.org"
      )
      puts "✅ Created Journey with ID: #{journey.id}"

      # Create journey steps for the journey detail tests - following journeys_spec.rb pattern
      step_types = [
        {type: 'landing', position: 1},
        {type: 'chapter', position: 2, chapter_number: 2},
        {type: 'embed', position: 3},
        {type: 'conclusion', position: 4}
      ]
      
      step_types.each do |step_config|
        step_attrs = {
          journey: journey,
          step_type: step_config[:type],
          title: "#{step_config[:type].capitalize} Step",
          subtitle: "Step subtitle for #{step_config[:type]}",
          description: "Description for #{step_config[:type]} step",
          content: "<p>Content for #{step_config[:type]} step</p>",
          position: step_config[:position],
          map_url: "/map"
        }
        step_attrs[:chapter_number] = step_config[:chapter_number] if step_config[:chapter_number]
        
        step = FactoryBot.create(:journey_step, step_attrs)
        puts "✅ Created JourneyStep #{step_config[:type]} with ID: #{step.id}"
      end
      
      journeys << journey
    end

    # Create homepage journey and homepage - following homepages_spec.rb pattern
    homepage_journey = FactoryBot.create(:homepage_journey,
      title: "Integration Test Journey",
      position: 1
    )
    puts "✅ Created HomepageJourney with ID: #{homepage_journey.id}"

    homepage = FactoryBot.create(:homepage,
      site_scope: site_scope,
      homepage_journey: homepage_journey,
      title: "Integration Test Homepage",
      subtitle: "Test subtitle for integration tests",
      credits: "Conservation International",
      credits_url: "https://www.conservation.org",
      show_journeys: true
    )
    puts "✅ Created Homepage with ID: #{homepage.id}"

    # Create homepage sections - following homepages_spec.rb pattern
    homepage_section = FactoryBot.create(:homepage_section,
      homepage: homepage,
      title: "Homepage Section",
      subtitle: "Homepage section subtitle",
      position: 1
    )
    puts "✅ Created HomepageSection with ID: #{homepage_section.id}"

    # Create site pages for the site endpoint - following sites_spec.rb pattern
    site_page = FactoryBot.create(:site_page,
      site_scope: site_scope,
      title: "Test Site Page",
      body: "Test site page content",
      priority: 1
    )
    puts "✅ Created SitePage with ID: #{site_page.id}"

    # Create layer group and layer for API endpoints
    layer_group = FactoryBot.create(:layer_group,
      name: "Test Layer Group",
      order: 1,
      icon_class: "test-icon",
      category: "Analysis",
      site_scope: site_scope
    )
    puts "✅ Created LayerGroup with ID: #{layer_group.id}"

    layer = FactoryBot.create(:layer,
      name: "Test Layer",
      layer_type: "CartoDB",
      slug: "test-layer",
      zoom_max: 10,
      zoom_min: 1,
      dashboard_order: 1,
      layer_provider: "cartodb",
      interaction_config: "{}"
    )
    puts "✅ Created Layer with ID: #{layer.id}"

    # Create agrupation to link layer to layer group
    agrupation = FactoryBot.create(:agrupation,
      layer: layer,
      layer_group: layer_group,
      active: true
    )
    puts "✅ Created Agrupation with ID: #{agrupation.id}"

    # Create About static page for /api/static_pages/about endpoint
    about_page = FactoryBot.create(:static_page,
      slug: "about",
      title: "About Integration Tests"
    )
    puts "✅ Created About StaticPage with ID: #{about_page.id}"

    # Create sections with proper relationships following the spec pattern
    # Create paragraph section with section_paragraph
    paragraph_section = FactoryBot.create(:static_page_section,
      static_page: about_page,
      slug: "content",
      title: "Content Section",
      title_size: 2,
      position: 1,
      show_at_navigation: true,
      section_type: "paragraph"
    )
    puts "✅ Created Paragraph StaticPage Section with ID: #{paragraph_section.id}"

    section_paragraph = FactoryBot.create(:static_page_section_paragraph,
      section: paragraph_section,
      text: "<p>This is test content for the paragraph section.</p>",
      image_position: "left"
    )
    puts "✅ Created StaticPage SectionParagraph with ID: #{section_paragraph.id}"

    # Create items section with section_items
    item_section = FactoryBot.create(:static_page_section,
      static_page: about_page,
      slug: "items",
      title: "Items Section", 
      title_size: 2,
      position: 2,
      show_at_navigation: true,
      section_type: "items"
    )
    puts "✅ Created Items StaticPage Section with ID: #{item_section.id}"

    # Create section items for the items section
    3.times do |i|
      item = FactoryBot.create(:static_page_section_item,
        section: item_section,
        slug: "item-#{i+1}",
        title: "Test Item #{i+1}",
        description: "<p>Description for test item #{i+1}</p>",
        position: i + 1
      )
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
      section_type: "references"
    )
    puts "✅ Created References StaticPage Section with ID: #{references_section.id}"

    # Create section references for the references section
    3.times do |i|
      reference = FactoryBot.create(:static_page_section_reference,
        section: references_section,
        slug: "reference-#{i+1}",
        position: i + 1
      )
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
    
    # Check that expected data exists
    required_data = {
      'SiteScope with ID 1' => -> { SiteScope.find_by(id: 1) },
      'Homepage' => -> { Homepage.first },
      'About StaticPage' => -> { StaticPage::Base.find_by(slug: 'about') },
      'LayerGroup' => -> { LayerGroup.first },
      'Layer' => -> { Layer.first },
      'Published Journey' => -> { Journey.where(published: true).first },
      'Journey Steps' => -> { JourneyStep.first }
    }

    all_good = true
    required_data.each do |name, check|
      if check.call
        puts "✅ #{name} exists"
      else
        puts "❌ #{name} missing"
        all_good = false
      end
    end

    if all_good
      puts "✅ All required integration test data is present"
    else
      puts "❌ Some required data is missing - run rake integration_test:setup_data"
      exit 1
    end
  end
end