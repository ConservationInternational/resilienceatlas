#!/bin/bash
# ============================================================================
# Common Functions for CodeDeploy Scripts
# ============================================================================
# This script contains shared functions and configuration used by all
# CodeDeploy lifecycle hook scripts.
#
# SINGLE-INSTANCE SUPPORT:
# Both staging and production can run on the same EC2 instance:
#   - Production: /opt/resilienceatlas-production (ports 3000, 3001)
#   - Staging:    /opt/resilienceatlas-staging    (ports 4000, 4001, 5433)
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Detect environment from CodeDeploy deployment group or hostname
detect_environment() {
    # First check CodeDeploy environment variable
    if [ -n "$DEPLOYMENT_GROUP_NAME" ]; then
        if echo "$DEPLOYMENT_GROUP_NAME" | grep -qi "staging"; then
            echo "staging"
            return
        elif echo "$DEPLOYMENT_GROUP_NAME" | grep -qi "production\|prod"; then
            echo "production"
            return
        fi
    fi
    
    # Check hostname
    HOSTNAME=$(hostname)
    if echo "$HOSTNAME" | grep -qi "staging"; then
        echo "staging"
        return
    elif echo "$HOSTNAME" | grep -qi "production\|prod"; then
        echo "production"
        return
    fi
    
    # Check for environment file markers
    if [ -f "/opt/resilienceatlas-staging/.env.staging" ]; then
        echo "staging"
        return
    elif [ -f "/opt/resilienceatlas-production/.env.production" ]; then
        echo "production"
        return
    fi
    
    # Default to staging for safety
    log_warning "Could not determine environment, defaulting to staging"
    echo "staging"
}

# Get application directory based on environment
# Each environment has its own directory to support single-instance deployments
get_app_directory() {
    local environment="$1"
    echo "/opt/resilienceatlas-${environment}"
}

# Get docker-compose file based on environment
get_compose_file() {
    local environment="$1"
    if [ "$environment" = "staging" ]; then
        echo "docker-compose.staging.yml"
    else
        echo "docker-compose.yml"
    fi
}

# Get docker project name based on environment
# This ensures containers don't conflict when both run on same instance
get_project_name() {
    local environment="$1"
    echo "resilienceatlas-${environment}"
}

# Get frontend port based on environment
get_frontend_port() {
    local environment="$1"
    if [ "$environment" = "production" ]; then
        echo "3000"
    else
        echo "4000"
    fi
}

# Get backend port based on environment
get_backend_port() {
    local environment="$1"
    if [ "$environment" = "production" ]; then
        echo "3001"
    else
        echo "4001"
    fi
}

# Get environment file based on environment
get_env_file() {
    local environment="$1"
    local app_dir=$(get_app_directory "$environment")
    if [ "$environment" = "staging" ]; then
        echo "$app_dir/.env.staging"
    else
        echo "$app_dir/.env.production"
    fi
}

# Wait for database to be ready (Docker Compose mode)
wait_for_database() {
    local compose_file="$1"
    local project_name="$2"
    local max_wait=60
    local wait_time=0
    
    log_info "Waiting for database to be ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        if docker compose -p "$project_name" -f "$compose_file" exec -T database pg_isready -U postgres >/dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        fi
        
        sleep 2
        wait_time=$((wait_time + 2))
    done
    
    log_error "Database did not become ready within $max_wait seconds"
    return 1
}

# Wait for database to be ready (Docker Swarm mode)
# Uses the Swarm service container instead of docker compose
wait_for_database_swarm() {
    local stack_name="$1"
    local max_wait=120
    local wait_time=0
    
    log_info "Waiting for Swarm database service to be ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        # Find the database container from the swarm stack
        local db_container
        db_container=$(docker ps --filter "name=${stack_name}_database" --format "{{.ID}}" 2>/dev/null | head -1)
        
        if [ -n "$db_container" ]; then
            if docker exec "$db_container" pg_isready -U postgres >/dev/null 2>&1; then
                log_success "Database is ready (container: $db_container)"
                return 0
            fi
        fi
        
        sleep 3
        wait_time=$((wait_time + 3))
    done
    
    log_error "Database did not become ready within $max_wait seconds"
    return 1
}

# Get database container ID from Swarm stack
get_swarm_db_container() {
    local stack_name="$1"
    docker ps --filter "name=${stack_name}_database" --format "{{.ID}}" 2>/dev/null | head -1
}

# Export the functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f detect_environment get_app_directory get_compose_file get_env_file
export -f get_project_name get_frontend_port get_backend_port
export -f wait_for_database wait_for_database_swarm get_swarm_db_container
