#!/bin/bash
set -e

echo "🧪 Testing specific backend fixes..."

# Run the backend container with specific tests that were failing
echo "🐳 Running focused backend tests in Docker..."

# Test the OEmbed controller fixes
echo "📋 Testing OEmbed controller fixes..."
docker compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "
    cd /app && 
    ./bin/test rspec spec/requests/api/v1/oembeds_spec.rb
  " || echo "❌ OEmbed tests failed"

# Test photo upload fixes  
echo "📸 Testing photo upload fixes..."
docker compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "
    cd /app && 
    ./bin/test rspec spec/requests/api/v1/photos_spec.rb
  " || echo "❌ Photo tests failed"

# Test layer download fixes (source translation issue)
echo "🗂️ Testing layer download fixes..."
docker compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "
    cd /app && 
    ./bin/test rspec spec/requests/api/v1/layers_spec.rb -e 'downloads'
  " || echo "❌ Layer download tests failed"

echo "✅ Focused testing completed"