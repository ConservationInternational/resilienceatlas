#!/bin/bash
# ============================================================================
# AfterInstall Hook - Configure application after files are deployed
# ============================================================================
# This script is executed after files are copied to the deployment location.
# It sets up the environment, builds Docker images, and configures the database.
#
# SINGLE-INSTANCE SUPPORT:
# The GitHub workflow modifies appspec.yml before creating the deployment package
# to set environment-specific destinations:
#   - Staging:    /opt/resilienceatlas-staging
#   - Production: /opt/resilienceatlas-production
# This prevents race conditions when both environments deploy simultaneously.
# ============================================================================

set -e

# Source common functions from our deployment directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "AfterInstall hook started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set application directory and project name
# CodeDeploy has already copied files to the environment-specific directory
APP_DIR=$(get_app_directory "$ENVIRONMENT")
PROJECT_NAME=$(get_project_name "$ENVIRONMENT")

cd "$APP_DIR"
log_info "Working directory: $APP_DIR"
log_info "Docker project name: $PROJECT_NAME"

# Get the appropriate docker-compose file
COMPOSE_FILE=$(get_compose_file "$ENVIRONMENT")
log_info "Using compose file: $COMPOSE_FILE"

# Load environment variables
ENV_FILE=$(get_env_file "$ENVIRONMENT")
if [ -f "$ENV_FILE" ]; then
    log_info "Loading environment variables from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
else
    log_warning "Environment file not found: $ENV_FILE"
    log_warning "Make sure to configure environment variables before deployment"
fi

# Set environment-specific variables
export RAILS_ENV="$ENVIRONMENT"
export NODE_ENV="production"

# Build Docker images with environment-specific tags
log_info "Building Docker images..."

# Build frontend with environment variables
log_info "Building frontend image..."
docker build -t "${PROJECT_NAME}-frontend:latest" \
    --target production \
    --build-arg NEXT_PUBLIC_API_HOST="${NEXT_PUBLIC_API_HOST:-}" \
    --build-arg NEXT_PUBLIC_GOOGLE_ANALYTICS="${NEXT_PUBLIC_GOOGLE_ANALYTICS:-}" \
    --build-arg NEXT_PUBLIC_TRANSIFEX_TOKEN="${NEXT_PUBLIC_TRANSIFEX_TOKEN:-}" \
    --build-arg NEXT_PUBLIC_TRANSIFEX_SECRET="${NEXT_PUBLIC_TRANSIFEX_SECRET:-}" \
    --build-arg NEXT_PUBLIC_GOOGLE_API_KEY="${NEXT_PUBLIC_GOOGLE_API_KEY:-}" \
    ./frontend

# Build backend
log_info "Building backend image..."
docker build -t "${PROJECT_NAME}-backend:latest" \
    --target production \
    ./backend

log_success "Docker images built successfully"

# Environment-specific setup
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Running staging-specific setup..."
    
    # Start database container first using project name
    log_info "Starting staging database container..."
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d database
    
    # Wait for database to be ready
    log_info "Waiting for database to be ready..."
    wait_for_database "$COMPOSE_FILE" "$PROJECT_NAME"
    
    # Sync production database to staging (if configured)
    if [ -n "$PRODUCTION_DATABASE_URL" ] && [ -n "$SYNC_PRODUCTION_DB" ] && [ "$SYNC_PRODUCTION_DB" = "true" ]; then
        log_info "Syncing production database to staging..."
        "${SCRIPT_DIR}/sync-database.sh" || {
            log_warning "Database sync failed, continuing with existing data"
        }
    else
        log_info "Skipping database sync (SYNC_PRODUCTION_DB not set or PRODUCTION_DATABASE_URL not configured)"
    fi
    
elif [ "$ENVIRONMENT" = "production" ]; then
    log_info "Running production-specific setup..."
    
    # Verify external database connectivity
    if [ -n "$PRODUCTION_DATABASE_URL" ]; then
        log_info "Testing production database connectivity..."
        
        # Parse database URL
        DB_HOST=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
        DB_PORT=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
        
        if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
            if timeout 10 bash -c "echo > /dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
                log_success "Production database is reachable"
            else
                log_warning "Cannot reach production database at $DB_HOST:$DB_PORT"
                log_warning "Deployment will continue, but application may fail to start"
            fi
        fi
    else
        log_warning "PRODUCTION_DATABASE_URL not set"
    fi
fi

# Set correct permissions
log_info "Setting file permissions..."
chown -R ubuntu:ubuntu "$APP_DIR"
chmod +x "$APP_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$APP_DIR/scripts/codedeploy/"*.sh 2>/dev/null || true

log_success "AfterInstall hook completed successfully"
exit 0
