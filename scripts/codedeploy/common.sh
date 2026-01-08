#!/bin/bash
# ============================================================================
# Common Functions for CodeDeploy Scripts
# ============================================================================
# This script contains shared functions and configuration used by all
# CodeDeploy lifecycle hook scripts.
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
    elif [ -f "/opt/resilienceatlas/.env.production" ]; then
        echo "production"
        return
    fi
    
    # Check EC2 instance tags
    if command -v aws &> /dev/null; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || true)
        if [ -n "$INSTANCE_ID" ]; then
            ENV_TAG=$(aws ec2 describe-tags \
                --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Environment" \
                --query 'Tags[0].Value' --output text 2>/dev/null || true)
            if [ -n "$ENV_TAG" ] && [ "$ENV_TAG" != "None" ]; then
                echo "$ENV_TAG" | tr '[:upper:]' '[:lower:]'
                return
            fi
        fi
    fi
    
    # Default to staging for safety
    log_warning "Could not determine environment, defaulting to staging"
    echo "staging"
}

# Get application directory based on environment
get_app_directory() {
    local environment="$1"
    if [ "$environment" = "production" ]; then
        echo "/opt/resilienceatlas"
    else
        echo "/opt/resilienceatlas"
    fi
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

# Wait for database to be ready
wait_for_database() {
    local compose_file="$1"
    local max_wait=60
    local wait_time=0
    
    log_info "Waiting for database to be ready..."
    
    while [ $wait_time -lt $max_wait ]; do
        if docker compose -f "$compose_file" exec -T database pg_isready -U postgres >/dev/null 2>&1; then
            log_success "Database is ready"
            return 0
        fi
        
        sleep 2
        wait_time=$((wait_time + 2))
    done
    
    log_error "Database did not become ready within $max_wait seconds"
    return 1
}

# Export the functions for use in other scripts
export -f log_info log_success log_warning log_error
export -f detect_environment get_app_directory get_compose_file get_env_file
export -f wait_for_database
