#!/bin/bash
set -e

echo "Testing tmp directory permissions in Docker container..."

# Run a quick test to see if we can create and write to tmp/rspec.xml
docker compose -f docker-compose.test.yml run --rm backend-test bash -c "
echo 'Current user:' \$(whoami)
echo 'Current working directory:' \$(pwd)
echo 'Contents of current directory:'
ls -la
echo 'Checking tmp directory:'
ls -la tmp/ 2>/dev/null || echo 'tmp directory does not exist'
echo 'Creating tmp directory if needed:'
mkdir -p tmp
echo 'Setting permissions:'
chmod 775 tmp
echo 'Checking if we can create rspec.xml:'
echo 'test content' > tmp/rspec.xml && echo 'SUCCESS: Can write to tmp/rspec.xml' || echo 'FAILED: Cannot write to tmp/rspec.xml'
echo 'Checking file permissions:'
ls -la tmp/rspec.xml 2>/dev/null || echo 'rspec.xml not found'
echo 'Removing test file:'
rm -f tmp/rspec.xml
echo 'Testing mkdir from script:'
./bin/test help | head -5
"