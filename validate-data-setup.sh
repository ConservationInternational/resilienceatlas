#!/bin/bash

# Simple test to validate data setup in development environment
# This tests the core data requirements for integration tests

echo "=== Resilience Atlas Data Validation ==="
echo

# Start the database
echo "1. Starting database..."
docker compose -f docker-compose.dev.yml up -d db
sleep 5

# Run the data validation
echo "2. Running data validation..."
docker compose -f docker-compose.dev.yml run --rm backend bash -c "
  bundle exec rails db:create db:migrate db:seed 2>/dev/null >/dev/null || echo 'Database setup failed'
  
  echo '=== Data Validation Results ==='
  echo
  
  # Check basic counts
  echo 'Basic counts:'
  bundle exec rails runner '
    puts \"  Homepages: #{Homepage.count}\"
    puts \"  Journeys: #{Journey.count}\"
    puts \"  StaticPages: #{StaticPage::Base.count}\"
    puts \"  JourneySteps: #{JourneyStep.count}\"
  '
  
  echo
  echo 'Homepage validation:'
  bundle exec rails runner '
    homepage = Homepage.first
    if homepage
      puts \"  ✓ Homepage exists: #{homepage.title}\"
      puts \"  ✓ Has background image: #{homepage.background_image.attached?}\"
      puts \"  ✓ Has credits: #{homepage.credits.present?}\"
      puts \"  ✓ Has credits_url: #{homepage.credits_url.present?}\"
      puts \"  ✓ Show journeys: #{homepage.show_journeys}\"
    else
      puts \"  ✗ No homepage found\"
    end
  '
  
  echo
  echo 'Journey validation:'
  bundle exec rails runner '
    journeys = Journey.only_published
    puts \"  Published journeys: #{journeys.count}\"
    journeys.each do |journey|
      bg_attached = journey.background_image.attached?
      puts \"  Journey #{journey.id} (#{journey.title}): bg_image=#{bg_attached}\"
    end
  '
  
  echo
  echo 'About page validation:'
  bundle exec rails runner '
    about_page = StaticPage::Base.find_by(slug: \"about\")
    if about_page
      puts \"  ✓ About page exists: #{about_page.title}\"
      puts \"  ✓ Has image: #{about_page.image.attached?}\"
      puts \"  ✓ Has sections: #{about_page.sections.count}\"
    else
      puts \"  ✗ No about page found\"
    end
  '
  
  echo
  echo '=== Testing API Responses ==='
  echo
  
  bundle exec rails runner '
    # Test homepage API response
    homepage = Homepage.first
    if homepage
      require \"active_model_serializers\"
      serialized = HomepageSerializer.new(homepage).as_json
      bg_image = serialized[:background_image]
      
      puts \"Homepage API response:\"
      puts \"  Has background_image: #{bg_image.present?}\"
      puts \"  Has original URL: #{bg_image&.key?(:original)}\" if bg_image
      puts \"  Background image structure: #{bg_image.keys.join(\", \")}\" if bg_image
    end
  '
  
  bundle exec rails runner '
    # Test journey API response
    journey = Journey.only_published.first
    if journey
      require \"active_model_serializers\"
      serialized = JourneySerializer.new(journey).as_json
      bg_image = serialized[:background_image]
      
      puts
      puts \"Journey API response:\"
      puts \"  Has background_image: #{bg_image.present?}\"
      puts \"  Has original URL: #{bg_image&.key?(:original)}\" if bg_image
      puts \"  Background image structure: #{bg_image.keys.join(\", \")}\" if bg_image
    end
  '
"

echo
echo "3. Cleaning up..."
docker compose -f docker-compose.dev.yml down

echo "=== Validation Complete ==="