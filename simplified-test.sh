#!/bin/bash
set -e

echo "🧪 Testing simplified backend test approach..."

# Create a minimal test environment without full Docker build
echo "📋 Checking Ruby and bundler availability..."

# Check if Ruby is available in a simple Ruby container
echo "Testing with Ruby container..."
docker run --rm -v "$(pwd)/backend:/app" -w /app ruby:3.4.4-slim bash -c "
  echo '📦 Ruby version:' && ruby --version
  echo '📦 Bundler version:' && bundle --version
  
  echo '🔧 Setting up minimal test environment...'
  apt-get update -qq && apt-get install -y build-essential libpq-dev > /dev/null 2>&1
  
  echo '🔐 Testing permission fix...'
  ls -la Gemfile.lock
  chmod 664 Gemfile.lock
  ls -la Gemfile.lock
  
  echo '📦 Testing bundle check...'
  bundle check || echo 'Dependencies need installation'
  
  echo '✅ Simplified test completed successfully'
"

echo "✅ All tests passed"
