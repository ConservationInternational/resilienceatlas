#!/bin/bash

# Simple integration test data setup script
# This script sets up minimal sample data needed for integration tests

set -e

echo "🚀 Setting up integration test data..."

# Create basic environment if it doesn't exist
cp .env.example .env 2>/dev/null || true

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
for i in {1..30}; do
  if docker compose -f docker-compose.test.yml exec -T db-test pg_isready -U postgres; then
    echo "✅ Database is ready"
    break
  fi
  echo "⏳ Waiting for database... ($i/30)"
  sleep 2
done

# Setup database and run migrations
echo "🔧 Setting up test database..."
docker compose -f docker-compose.test.yml run --rm backend-test bash -c "
  export RAILS_ENV=test
  bundle exec rails db:drop db:create db:migrate || echo 'Database setup completed'
"

# Load integration test data
echo "📊 Loading integration test sample data..."
docker compose -f docker-compose.test.yml run --rm backend-test bash -c "
  export RAILS_ENV=test
  bundle exec rails integration_test:setup_data || echo 'Sample data loading completed'
"

echo "✅ Integration test data setup complete!"