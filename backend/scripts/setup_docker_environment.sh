#!/bin/bash
set -e

# Docker Environment Setup Script
# This script sets up the Docker test environment for workflows
# Used by both backend_tests.yml and integration_tests.yml workflows

echo "🐳 Docker Environment Setup Script Starting..."

# Create test environment file
create_env_file() {
    local db_name="${1:-resilienceatlas_test}"
    local env_type="${2:-backend}"  # backend or integration
    
    echo "Creating .env.test file for database: $db_name (type: $env_type)"
    
    if [ "$env_type" = "integration" ]; then
        # Integration tests need both backend and frontend env vars
        cat > .env.test << EOF
# Backend environment
RAILS_ENV=test
DATABASE_URL=postgres://postgres:postgres@db-test:5432/$db_name
DATABASE_HOST=db-test
DATABASE_PORT=5432
DATABASE_NAME=$db_name
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
SECRET_KEY_BASE=integration_test_secret_key_base_that_is_long_enough_for_rails_to_accept_it_properly
DEVISE_KEY=integration_test_devise_key_that_is_also_long_enough_for_the_application_to_work
REDIS_URL=redis://redis-test:6379/1
BACKEND_URL=http://backend-test:3001
FRONTEND_URL=http://frontend-test:3000
CORS_ORIGINS=http://frontend-test:3000,http://localhost:3000

# Frontend environment
NODE_ENV=test
NEXT_PUBLIC_API_HOST=http://backend-test:3001
NEXT_PUBLIC_GOOGLE_ANALYTICS=GA_INTEGRATION_TEST_ID
NEXT_PUBLIC_GOOGLE_API_KEY=integration_test_api_key
PORT=3000
EOF
    else
        # Backend-only tests
        cat > .env.test << EOF
RAILS_ENV=test
DATABASE_URL=postgres://postgres:postgres@db-test:5432/$db_name
DATABASE_HOST=db-test
DATABASE_PORT=5432
DATABASE_NAME=$db_name
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
SECRET_KEY_BASE=test_secret_key_base_that_is_long_enough_for_rails_to_accept_it_properly
DEVISE_KEY=test_devise_key_that_is_also_long_enough_for_the_application_to_work
REDIS_URL=redis://redis-test:6379/0
EOF
    fi
    echo "✅ Environment file created"
}

# Start test services
start_services() {
    echo "Starting test database and services..."
    docker compose -f docker-compose.test.yml up -d db-test redis-test
    
    echo "Waiting for database to be ready..."
    timeout 60s bash -c 'until docker compose -f docker-compose.test.yml exec -T db-test pg_isready -U postgres; do sleep 2; done'
    
    echo "✅ Infrastructure services started"
}

# Ensure host directories exist for volume mounts
setup_host_directories() {
    echo "Setting up host directories for volume mounts..."
    mkdir -p backend/tmp
    chmod 777 backend/tmp  # Allow container to write test results back to host
    echo "✅ Host directories prepared"
}

# Main execution
case "${1:-all}" in
    "env")
        create_env_file "${2:-resilienceatlas_test}" "${3:-backend}"
        ;;
    "services")
        start_services
        ;;
    "directories")
        setup_host_directories
        ;;
    "all")
        setup_host_directories
        # For integration tests, detect if we need integration env
        if [[ "${2:-}" == *"integration"* ]]; then
            create_env_file "${2:-resilienceatlas_test}" "integration"
        else
            create_env_file "${2:-resilienceatlas_test}" "backend"
        fi
        start_services
        ;;
    *)
        echo "Usage: $0 {env|services|directories|all} [database_name] [env_type]"
        echo "  env [db_name] [env_type]  - Create .env.test file with specified database name and type (backend/integration)"
        echo "  services                   - Start Docker test services"
        echo "  directories                - Setup host directories for volume mounts"
        echo "  all [db_name]             - Run all setup steps with specified database name (auto-detects integration tests)"
        exit 1
        ;;
esac

echo "🐳 Docker environment setup completed"
