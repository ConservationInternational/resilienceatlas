#!/bin/bash
set -e

echo "🚀 Resilience Atlas Test Infrastructure Validation"
echo "================================================="

# Function to check service health
check_service_health() {
    local service_name=$1
    local health_url=$2
    local max_attempts=${3:-30}
    local attempt=1
    
    echo "🔍 Checking $service_name health..."
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$health_url" >/dev/null 2>&1; then
            echo "✅ $service_name is healthy"
            return 0
        elif [ $attempt -eq $max_attempts ]; then
            echo "❌ $service_name failed health check after $max_attempts attempts"
            return 1
        else
            echo "⏳ Attempt $attempt/$max_attempts - $service_name not ready, waiting..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
}

# Function to run command with error handling
run_with_error_handling() {
    local description=$1
    local command=$2
    
    echo "🔄 $description"
    if eval "$command"; then
        echo "✅ $description completed successfully"
    else
        echo "❌ $description failed"
        return 1
    fi
}

# Validate Docker environment
echo "🐳 Validating Docker environment..."
docker --version || { echo "❌ Docker not available"; exit 1; }
docker compose version || { echo "❌ Docker Compose not available"; exit 1; }

# Clean up any existing test containers
echo "🧹 Cleaning up existing test containers..."
docker compose -f docker-compose.test.yml down -v --remove-orphans

# Start infrastructure services
echo "🏗️ Starting infrastructure services..."
run_with_error_handling "Starting database and Redis" \
    "docker compose -f docker-compose.test.yml up -d db-test redis-test"

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure services..."
timeout 60s bash -c 'until docker compose -f docker-compose.test.yml exec -T db-test pg_isready -U postgres; do sleep 2; done'
timeout 30s bash -c 'until docker compose -f docker-compose.test.yml exec -T redis-test redis-cli ping | grep -q PONG; do sleep 2; done'

# Build and start backend
echo "🔧 Building and starting backend..."
run_with_error_handling "Building backend test image" \
    "docker buildx build --target test --tag resilienceatlas-backend:test --load ./backend"

run_with_error_handling "Starting backend service" \
    "docker compose -f docker-compose.test.yml up -d backend-test"

# Wait for backend health
check_service_health "Backend" "http://localhost:3001/api/health" 36

# Build and start frontend
echo "🎨 Building and starting frontend..."
run_with_error_handling "Building frontend test image" \
    "docker buildx build --target test --tag resilienceatlas-frontend:test --load ./frontend"

run_with_error_handling "Starting frontend service" \
    "docker compose -f docker-compose.test.yml up -d frontend-test"

# Wait for frontend health
check_service_health "Frontend" "http://localhost:3000" 60

# Test full stack connectivity
echo "🌐 Testing full stack connectivity..."
run_with_error_handling "Testing backend API" \
    "curl -f http://localhost:3001/api/health"

run_with_error_handling "Testing frontend response" \
    "curl -f http://localhost:3000"

run_with_error_handling "Testing frontend-to-backend connectivity" \
    "docker compose -f docker-compose.test.yml exec -T frontend-test curl -f http://backend-test:3001/api/health"

# Run quick backend tests
echo "🧪 Running quick backend validation tests..."
run_with_error_handling "Backend lint check" \
    "docker compose -f docker-compose.test.yml run --rm backend-test bash -c 'chmod +x ./bin/test && ./bin/test lint'"

run_with_error_handling "Backend security check" \
    "docker compose -f docker-compose.test.yml run --rm backend-test bash -c 'chmod +x ./bin/test && ./bin/test security'"

# Run quick frontend tests
echo "🎨 Running quick frontend validation tests..."
run_with_error_handling "Frontend lint check" \
    "docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test bash -c 'chmod +x ./bin/test && ./bin/test lint'"

run_with_error_handling "Frontend type check" \
    "docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test bash -c 'chmod +x ./bin/test && ./bin/test type-check'"

# Test Chrome functionality for system tests
echo "🌐 Testing Chrome functionality..."
run_with_error_handling "Chrome wrapper test" \
    "docker compose -f docker-compose.test.yml run --rm backend-test bash -c 'chmod +x ./bin/test && timeout 30 ./bin/test verify-chrome'"

# Show service status
echo "📊 Service Status Summary:"
echo "========================="
docker compose -f docker-compose.test.yml ps

echo ""
echo "🎉 Test Infrastructure Validation Complete!"
echo "All core components are working correctly."
echo ""
echo "To run full test suites:"
echo "  Backend:     docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test all"
echo "  Frontend:    docker compose -f docker-compose.test.yml run --rm frontend-test ./bin/test all"
echo ""
echo "To clean up:"
echo "  docker compose -f docker-compose.test.yml down -v"