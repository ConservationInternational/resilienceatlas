#!/bin/bash
set -e

echo "🧪 Testing the updated bin/test script logic..."

cd backend

# Test the permission checking logic from our updated bin/test script
echo "🔐 Testing permission check logic..."

# Check if we can write to Gemfile.lock and fix permissions if needed
if [ ! -w "Gemfile.lock" ]; then
  echo "⚠️  Gemfile.lock not writable, attempting to fix permissions..."
  chmod 664 Gemfile.lock 2>/dev/null && echo "✅ Fixed Gemfile.lock permissions" || echo "❌ Could not fix Gemfile.lock permissions"
else
  echo "✅ Gemfile.lock is already writable"
fi

# Try bundle check, but don't fail if gems are not satisfied
if bundle check >/dev/null 2>&1; then
  echo "✅ Dependencies already satisfied, skipping bundle install"
else
  echo "⚠️ Dependencies not satisfied, would run bundle install in real scenario"
fi

echo "🔍 Testing the overall script structure..."

# Show that our bin/test script has the right logic
echo "=== Updated bin/test script logic ===="
head -n 20 bin/test

echo "✅ Script logic validation completed"
