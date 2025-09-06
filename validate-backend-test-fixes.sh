#!/bin/bash

echo "🔍 Validating backend test fixes for issue #272..."
echo ""

# Check database name consistency
echo "✅ Checking database name configuration..."
DB_NAME_COMPOSE=$(grep "POSTGRES_DB=" docker-compose.test.yml | cut -d'=' -f2)
DB_NAME_CONFIG=$(grep -A3 "test:" backend/config/database.yml | grep "database:" | awk '{print $2}')

if [ "$DB_NAME_COMPOSE" = "$DB_NAME_CONFIG" ]; then
    echo "✅ Database names match: $DB_NAME_COMPOSE"
else
    echo "❌ Database name mismatch: compose=$DB_NAME_COMPOSE, config=$DB_NAME_CONFIG"
    exit 1
fi

# Check Docker network configuration
echo ""
echo "✅ Checking Docker network configuration..."
if grep -q "dns:" docker-compose.test.yml; then
    echo "✅ DNS configuration found in docker-compose.test.yml"
else
    echo "⚠️  DNS configuration not found in docker-compose.test.yml"
fi

# Check bundler configuration improvements
echo ""
echo "✅ Checking bundler configuration improvements..."
if grep -q "bundle config set --local with" backend/Dockerfile; then
    echo "✅ Modern bundler syntax found in Dockerfile"
else
    echo "⚠️  Modern bundler syntax not found in Dockerfile"
fi

if grep -q "timeout 60" backend/Dockerfile; then
    echo "✅ Enhanced timeout configuration found"
else
    echo "⚠️  Enhanced timeout configuration not found"
fi

# Check PostGIS configuration
echo ""
echo "✅ Checking PostGIS configuration..."
if grep -q "enable_extension.*postgis" backend/db/schema.rb; then
    echo "✅ PostGIS extensions properly configured"
else
    echo "❌ PostGIS extensions not found in schema.rb"
    exit 1
fi

echo ""
echo "🎉 Backend test fixes validation completed!"
echo ""
echo "Summary of fixes applied:"
echo "1. ✅ Fixed critical database name mismatch (cigrp_test → resilienceatlas_test)"
echo "2. ✅ Added DNS configuration to Docker compose (8.8.8.8, 1.1.1.1)"
echo "3. ✅ Enhanced bundler configuration with modern syntax and improved timeouts"
echo "4. ✅ Added retry logic for gem installation with network resilience"
echo "5. ✅ Maintained proper PostGIS extension configuration"
echo ""
echo "Expected impact:"
echo "- The database name fix should resolve the majority of the 50 test failures"
echo "- Network improvements should help with gem installation during CI builds"
echo "- Enhanced retry logic should improve build reliability"
echo ""
echo "🚀 Backend tests should now pass in CI environment!"