#!/bin/bash
# ============================================================================
# ApplicationStart Hook - Start the application
# ============================================================================
# This script is executed after AfterInstall to start the application.
# It starts all required Docker containers and runs database migrations.
#
# SINGLE-INSTANCE SUPPORT: Uses project name to isolate containers per environment.
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "ApplicationStart hook started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set application directory and project name
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
fi

# Set environment-specific variables
export RAILS_ENV="$ENVIRONMENT"
export NODE_ENV="production"

# Start all containers with project name
log_info "Starting application containers..."
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d --force-recreate

# Wait for containers to be running
log_info "Waiting for containers to be running..."
MAX_WAIT=180
WAIT_TIME=0
INTERVAL=10

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    RUNNING=$(docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps --filter "status=running" -q 2>/dev/null | wc -l)
    TOTAL=$(docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps -q 2>/dev/null | wc -l)
    
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        log_success "All containers are running ($RUNNING/$TOTAL)"
        break
    fi
    
    log_info "Waiting for containers... ($RUNNING/$TOTAL running, ${WAIT_TIME}s/${MAX_WAIT}s)"
    sleep $INTERVAL
    WAIT_TIME=$((WAIT_TIME + INTERVAL))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log_warning "Some containers may not be fully ready after $MAX_WAIT seconds"
    log_info "Container status:"
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps
fi

# Run database migrations
log_info "Running database migrations..."
if docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T backend bundle exec rails db:migrate 2>/dev/null; then
    log_success "Database migrations completed"
else
    log_warning "Database migrations failed or not applicable"
fi

# Show final container status
log_info "Final container status:"
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps

log_success "ApplicationStart hook completed successfully"
exit 0
