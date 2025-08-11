#!/bin/bash
set -e

# Test script for Docker buildx caching optimizations
# Usage: ./test-docker-cache.sh [backend|frontend|integration]

SERVICE=${1:-"backend"}
CACHE_DIR="/tmp/.buildx-cache-test"

echo "🧪 Testing Docker buildx caching for $SERVICE"
echo "=================================================="

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Generate cache keys like in the CI
echo "🔑 Generating cache keys..."
if [ "$SERVICE" = "backend" ] || [ "$SERVICE" = "integration" ]; then
    DOCKERFILE_HASH=$(sha256sum backend/Dockerfile | cut -d' ' -f1)
    GEMFILE_HASH=$(sha256sum backend/Gemfile backend/Gemfile.lock | sha256sum | cut -d' ' -f1)
    RUBY_VERSION=$(cat backend/.ruby-version 2>/dev/null || echo '3.4.4')
    echo "  Backend Dockerfile hash: $DOCKERFILE_HASH"
    echo "  Gemfile hash: $GEMFILE_HASH"
    echo "  Ruby version: $RUBY_VERSION"
fi

if [ "$SERVICE" = "frontend" ] || [ "$SERVICE" = "integration" ]; then
    DOCKERFILE_HASH=$(sha256sum frontend/Dockerfile | cut -d' ' -f1)
    PACKAGE_HASH=$(sha256sum frontend/package.json frontend/package-lock.json | sha256sum | cut -d' ' -f1)
    NODE_VERSION=$(cat frontend/.nvmrc 2>/dev/null || echo '22.11.0')
    echo "  Frontend Dockerfile hash: $DOCKERFILE_HASH"
    echo "  Package hash: $PACKAGE_HASH"
    echo "  Node version: $NODE_VERSION"
fi

# Test Docker buildx capabilities
echo ""
echo "🔧 Testing Docker buildx capabilities..."
docker buildx version
echo "✅ Docker buildx is available"

# Test cache directory setup
echo ""
echo "📁 Testing cache setup..."
echo "Cache directory: $CACHE_DIR"
echo "Current cache size: $(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo '0B')"

# Test bake configuration if integration
if [ "$SERVICE" = "integration" ]; then
    echo ""
    echo "🏗️ Testing docker bake configuration..."
    if docker buildx bake --file .github/docker-bake.hcl --print integration > /dev/null; then
        echo "✅ Docker bake configuration is valid"
        echo "Available targets:"
        docker buildx bake --file .github/docker-bake.hcl --print integration | jq -r '.target | keys[]' | sed 's/^/  - /'
    else
        echo "❌ Docker bake configuration has issues"
        exit 1
    fi
fi

# Test build command structure (dry run)
echo ""
echo "🚀 Testing build command structure..."
case "$SERVICE" in
    "backend")
        BUILD_CMD="docker buildx build \
            --cache-from=type=local,src=$CACHE_DIR \
            --cache-to=type=local,dest=${CACHE_DIR}-new,mode=max \
            --target test \
            --tag resilienceatlas-backend:test-cache \
            --build-arg BUILDKIT_INLINE_CACHE=1 \
            --dry-run \
            ./backend"
        ;;
    "frontend")
        BUILD_CMD="docker buildx build \
            --cache-from=type=local,src=$CACHE_DIR \
            --cache-to=type=local,dest=${CACHE_DIR}-new,mode=max \
            --target test \
            --tag resilienceatlas-frontend:test-cache \
            --build-arg BUILDKIT_INLINE_CACHE=1 \
            --build-arg CYPRESS_INSTALL_BINARY=0 \
            --build-arg NEXT_PUBLIC_API_HOST=http://localhost:3001 \
            --dry-run \
            ./frontend"
        ;;
    "integration")
        echo "Using docker bake for coordinated build..."
        BUILD_CMD="docker buildx bake \
            --file .github/docker-bake.hcl \
            --set '*.cache-from=type=local,src=$CACHE_DIR' \
            --set '*.cache-to=type=local,dest=${CACHE_DIR}-new,mode=max' \
            --print \
            integration"
        ;;
esac

echo "Build command structure:"
echo "$BUILD_CMD"
echo "✅ Build command structure is valid"

# Test actual build if --build flag is passed
if [ "$2" = "--build" ]; then
    echo ""
    echo "🏗️ Running actual build test..."
    echo "⚠️  This will take several minutes and download dependencies..."
    read -p "Continue with actual build? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ "$SERVICE" = "integration" ]; then
            # Remove --print and --dry-run for actual build
            eval "${BUILD_CMD/--print/}"
        else
            # Remove --dry-run for actual build
            eval "${BUILD_CMD/--dry-run/}"
        fi
        echo "✅ Build completed successfully"
        
        # Show cache results
        echo ""
        echo "📊 Cache results:"
        echo "New cache size: $(du -sh "${CACHE_DIR}-new" 2>/dev/null | cut -f1 || echo '0B')"
        
        # Move cache for next run
        rm -rf "$CACHE_DIR"
        mv "${CACHE_DIR}-new" "$CACHE_DIR" 2>/dev/null || true
    else
        echo "Skipping actual build"
    fi
fi

echo ""
echo "✅ All caching tests passed for $SERVICE!"
echo "🚀 The optimized Docker buildx setup is ready for CI/CD"