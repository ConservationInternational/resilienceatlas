#!/bin/bash

# Quick test script to validate our fixes
# Tests both backend linting and basic integration test setup

set -e

echo "🧪 Quick validation of integration test fixes..."

echo "1️⃣ Testing Ruby syntax fix..."
docker run --rm -v $(pwd)/backend:/code -w /code ruby:3.4.8-bullseye ruby -c app/controllers/api/v1/oembeds_controller.rb
echo "✅ Ruby syntax check passed"

echo "2️⃣ Checking Docker environment setup..."
if [ -f ".env.test" ]; then
    echo "✅ Test environment file exists"
else
    echo "⚠️  Test environment file missing"
fi

echo "3️⃣ Checking database connectivity..."
if docker ps | grep -q "resilienceatlas-db-test-1"; then
    echo "✅ Test database is running"
    if docker compose -f docker-compose.test.yml exec -T db-test pg_isready -U postgres >/dev/null 2>&1; then
        echo "✅ Test database is accepting connections"
    else
        echo "⚠️  Test database not ready for connections"
    fi
else
    echo "⚠️  Test database not running"
fi

echo "4️⃣ Testing integration test script..."
cd integration-tests
if npm list >/dev/null 2>&1; then
    echo "✅ Integration test dependencies installed"
else
    echo "⚠️  Integration test dependencies may be missing"
fi

echo "5️⃣ Checking for backend test image..."
if docker images | grep -q "resilienceatlas.*test"; then
    echo "✅ Backend test image exists"
else
    echo "⚠️  Backend test image not found"
fi

echo ""
echo "📋 Summary of fixes applied:"
echo "   - Fixed OEmbed controller host parsing safety"
echo "   - Made backend setup scripts executable" 
echo "   - Created integration test data setup script"
echo "   - Validated Ruby syntax changes"
echo ""
echo "✅ Quick validation complete!"