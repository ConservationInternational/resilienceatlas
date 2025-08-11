#!/bin/bash
set -e

echo "Testing permission fix for Gemfile.lock..."

# Check current permissions
echo "Current permissions:"
ls -la backend/Gemfile.lock

# Test if we can make it writable
echo "Testing permission fix with chmod..."
chmod 664 backend/Gemfile.lock && echo "✅ chmod succeeded" || echo "❌ chmod failed"

# Check new permissions
echo "After chmod:"
ls -la backend/Gemfile.lock

# Test that our bin/test script logic works
echo "Testing bin/test permission logic..."
cd backend

# Check if bundle check works
echo "Testing bundle check..."
if bundle check >/dev/null 2>&1; then
  echo "✅ Bundle check passed - dependencies satisfied"
else 
  echo "⚠️ Bundle check failed - would need bundle install"
fi

echo "✅ Permission tests completed"
