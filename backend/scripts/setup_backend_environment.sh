#!/bin/bash
set -e

# Backend Environment Setup Script
# This script sets up the backend test environment including directories, permissions, and database
# Used by both backend_tests.yml and integration_tests.yml workflows

echo "🔧 Backend Environment Setup Script Starting..."

# Function to fix directory permissions
fix_directory_permissions() {
    local dir="$1"
    local description="$2"
    
    echo "🔧 Setting up $description..."
    mkdir -p "$dir" 2>/dev/null || true
    
    if [ -d "$dir" ] && [ ! -w "$dir" ]; then
        echo "⚠️  $dir directory not writable, attempting to fix permissions..."
        if command -v sudo >/dev/null 2>&1; then
            sudo chmod 775 "$dir" 2>/dev/null || echo "Could not fix $dir permissions"
            sudo chown $(whoami):$(whoami) "$dir" 2>/dev/null || echo "Could not fix $dir ownership"
        else
            chmod 775 "$dir" 2>/dev/null || echo "Could not fix $dir permissions without sudo"
        fi
    fi
    
    # Test write permissions
    if echo "test" > "$dir/write_test.tmp" 2>/dev/null; then
        rm -f "$dir/write_test.tmp" 2>/dev/null || true
        echo "✅ $description is writable"
        return 0
    else
        echo "❌ Cannot write to $description"
        return 1
    fi
}

# Setup all required directories
echo "🔧 Setting up required directories..."

# Core Rails directories
mkdir -p tmp tmp/cache tmp/pids tmp/sockets tmp/storage 2>/dev/null || true
mkdir -p log 2>/dev/null || true
mkdir -p public/storage public/uploads public/uploads/cache public/uploads/store 2>/dev/null || true
mkdir -p downloads storage 2>/dev/null || true

# Fix ownership and permissions for volume-mounted directories (Docker issue)
echo "🔧 Ensuring proper ownership and permissions for directories..."
if command -v sudo >/dev/null 2>&1; then
    ownership_fixed=true
    permissions_fixed=true
    
    sudo chown -R $(whoami):$(whoami) public/storage public/uploads downloads storage log tmp 2>/dev/null || {
        echo "Could not fix ownership"
        ownership_fixed=false
    }
    
    sudo chmod -R 775 public/storage public/uploads downloads storage log tmp 2>/dev/null || {
        echo "Could not fix permissions"
        permissions_fixed=false
    }
    
    if [ "$ownership_fixed" = true ] && [ "$permissions_fixed" = true ]; then
        echo "✅ Directory ownership and permissions fixed"
    else
        echo "⚠️  Some directory ownership and permissions could not be fixed, but continuing..."
    fi
else
    echo "⚠️ sudo not available, attempting permission fix without sudo..."
    chown -R $(whoami):$(whoami) public/storage public/uploads downloads storage log tmp 2>/dev/null || echo "Cannot fix ownership without sudo"
    chmod -R 775 public/storage public/uploads downloads storage log tmp 2>/dev/null || echo "Cannot fix permissions without sudo"
fi

# Setup Rails log file
echo "🔧 Setting up Rails test.log file..."
if [ ! -f "log/test.log" ]; then
    touch log/test.log 2>/dev/null || {
        echo "⚠️  Cannot create log/test.log, attempting with sudo..."
        if command -v sudo >/dev/null 2>&1; then
            sudo touch log/test.log 2>/dev/null || true
            sudo chown $(whoami):$(whoami) log/test.log 2>/dev/null || true
        fi
    }
fi

# Ensure log file is writable
if [ -f "log/test.log" ] && [ ! -w "log/test.log" ]; then
    echo "⚠️  log/test.log not writable, fixing permissions..."
    if command -v sudo >/dev/null 2>&1; then
        sudo chmod 664 log/test.log 2>/dev/null || echo "Could not fix log/test.log permissions"
        sudo chown $(whoami):$(whoami) log/test.log 2>/dev/null || echo "Could not fix log/test.log ownership"
    else
        chmod 664 log/test.log 2>/dev/null || echo "Could not fix log/test.log permissions without sudo"
    fi
fi

if [ -f "log/test.log" ] && [ -w "log/test.log" ]; then
    echo "✅ Rails test.log file is writable"
else
    echo "⚠️  Rails test.log file may not be accessible, but continuing..."
fi

# Test directory write permissions
echo "🔍 Testing directory write permissions..."
failed_dirs=()

for dir in tmp log public/storage public/uploads/cache downloads; do
    if [ -d "$dir" ]; then
        if ! fix_directory_permissions "$dir" "$dir directory"; then
            failed_dirs+=("$dir")
        fi
    fi
done

if [ ${#failed_dirs[@]} -gt 0 ]; then
    echo "⚠️  Some directories may not be fully writable: ${failed_dirs[*]}"
    echo "Current user: $(whoami)"
    echo "Current user groups: $(groups)"
else
    echo "✅ All directories are writable"
fi

echo "🔧 Backend environment setup completed"
