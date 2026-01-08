#!/bin/bash

# Script to fix upload permissions for photo uploads

echo "Setting up upload directory permissions..."

# Ensure upload directories exist with correct permissions
mkdir -p backend/public/uploads/cache
mkdir -p backend/public/uploads/store

# Set ownership to the Docker user (usually www-data or app)
sudo chown -R 1000:1000 backend/public/uploads/

# Set permissions to allow read/write
chmod -R 775 backend/public/uploads/

echo "Upload directory permissions set:"
ls -la backend/public/uploads/

echo "Testing write access..."
touch backend/public/uploads/test_write.tmp
if [ $? -eq 0 ]; then
    echo "✓ Write access confirmed"
    rm -f backend/public/uploads/test_write.tmp
else
    echo "✗ Write access failed"
    exit 1
fi