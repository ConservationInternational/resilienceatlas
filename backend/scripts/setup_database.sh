#!/bin/bash
set -e

# Database Setup Script
# This script sets up the test database for both unit tests and integration tests
# Used by both backend_tests.yml and integration_tests.yml workflows

echo "🗄️  Database Setup Script Starting..."

# Get the database name from environment or use default
DB_NAME="${DATABASE_NAME:-resilienceatlas_test}"
SETUP_DATA="${SETUP_INTEGRATION_DATA:-false}"

echo "Setting up database: $DB_NAME"
echo "Setup integration data: $SETUP_DATA"

# Setup database with proper error handling
echo "Setting Rails environment..."
RAILS_ENV=test bundle exec rails db:environment:set RAILS_ENV=test || true

# Try db:prepare first, but if it fails due to schema conflicts, use drop/create/migrate
echo "Preparing test database..."
if ! RAILS_ENV=test bundle exec rails db:prepare 2>&1; then
    echo "⚠️  db:prepare failed, attempting drop/create/migrate approach..."
    
    # Drop database if it exists (ignore errors if it doesn't)
    RAILS_ENV=test bundle exec rails db:drop 2>/dev/null || true
    
    # Create database
    echo "Creating database..."
    RAILS_ENV=test bundle exec rails db:create
    
    # Run migrations instead of schema:load to avoid topology schema conflict
    echo "Running migrations..."
    RAILS_ENV=test bundle exec rails db:migrate
fi

echo "Verifying database setup..."
table_count=$(RAILS_ENV=test bundle exec rails runner 'puts ActiveRecord::Base.connection.tables.count')
echo "Database ready with $table_count tables"

# Setup integration test data if requested
if [ "$SETUP_DATA" = "true" ]; then
    echo "Setting up integration test data..."
    RAILS_ENV=test bundle exec rake integration_test:setup_data || {
        echo "❌ Integration test data setup failed"
        exit 1
    }
    
    echo "Verifying integration test data..."
    RAILS_ENV=test bundle exec rake integration_test:verify_data || {
        echo "❌ Integration test data verification failed"
        exit 1
    }
    
    echo "✅ Integration test data setup completed"
fi

echo "✅ Database setup completed successfully"
