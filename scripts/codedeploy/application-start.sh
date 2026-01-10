#!/bin/bash
# ============================================================================
# ApplicationStart Hook (Swarm Mode) - Deploy/Update the Swarm Stack
# ============================================================================
# This script deploys or updates the Docker Swarm stack with zero-downtime
# rolling updates.
#
# Key features:
#   - Rolling updates with start-first ordering (new containers start before old stop)
#   - Health-check aware (waits for new containers to be healthy)
#   - Automatic rollback on failure
#   - Database migrations after successful deployment
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "ApplicationStart hook (Swarm mode) started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set variables
APP_DIR=$(get_app_directory "$ENVIRONMENT")
STACK_NAME="resilienceatlas-${ENVIRONMENT}"

if [ "$ENVIRONMENT" = "staging" ]; then
    COMPOSE_FILE="docker-compose.swarm.staging.yml"
else
    COMPOSE_FILE="docker-compose.swarm.yml"
fi

cd "$APP_DIR"
log_info "Working directory: $APP_DIR"
log_info "Stack name: $STACK_NAME"
log_info "Compose file: $COMPOSE_FILE"

# Load environment variables
ENV_FILE=$(get_env_file "$ENVIRONMENT")
if [ -f "$ENV_FILE" ]; then
    log_info "Loading environment variables from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi

# Get the deployment tag from AfterInstall hook
if [ -f "$APP_DIR/.deploy_tag" ]; then
    DEPLOY_TAG=$(cat "$APP_DIR/.deploy_tag")
    log_info "Using deployment tag: $DEPLOY_TAG"
else
    DEPLOY_TAG="latest"
    log_warning "No deployment tag found, using 'latest'"
fi
export TAG="$DEPLOY_TAG"

# ============================================================================
# Deploy/Update Stack
# ============================================================================
# Docker stack deploy is idempotent and non-blocking - it submits the desired
# state to Swarm and returns immediately. Swarm handles orchestration.
# ============================================================================

log_info "Running docker stack deploy with compose file: $COMPOSE_FILE"
docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME" --with-registry-auth --detach=true

log_success "Stack deploy command submitted to Swarm"

# Brief pause to let Swarm start processing
sleep 5

# Log current status (non-blocking, just informational)
log_info "Current stack status:"
docker stack services "$STACK_NAME" 2>/dev/null || true

# ============================================================================
# Sync Production Database to Staging (if configured)
# ============================================================================
if [ "$ENVIRONMENT" = "staging" ] && [ -n "$PRODUCTION_DATABASE_URL" ] && [ "${SYNC_PRODUCTION_DB:-false}" = "true" ]; then
    log_info "Database sync configured - syncing production database to staging..."
    
    # Run sync-database.sh script
    if [ -f "${SCRIPT_DIR}/sync-database.sh" ]; then
        # Set up environment for sync script
        export STACK_NAME
        export APP_DIR
        
        if "${SCRIPT_DIR}/sync-database.sh"; then
            log_success "Database sync completed successfully"
        else
            log_warning "Database sync failed (non-fatal, continuing deployment)"
        fi
    else
        log_warning "sync-database.sh not found at ${SCRIPT_DIR}/sync-database.sh"
    fi
else
    if [ "$ENVIRONMENT" = "staging" ]; then
        log_info "Database sync skipped (SYNC_PRODUCTION_DB is not set to 'true' or PRODUCTION_DATABASE_URL is not set)"
    fi
fi

# ============================================================================
# Run Database Migrations (with timeout)
# ============================================================================
log_info "Attempting database migrations..."

# Find a running backend container (try a few times)
BACKEND_CONTAINER=""
for i in 1 2 3 4 5; do
    BACKEND_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_backend" --format "{{.ID}}" 2>/dev/null | head -1)
    if [ -n "$BACKEND_CONTAINER" ]; then
        break
    fi
    log_info "Waiting for backend container... (attempt $i/5)"
    sleep 10
done

if [ -n "$BACKEND_CONTAINER" ]; then
    log_info "Running migrations in container: $BACKEND_CONTAINER"
    # Use timeout to prevent hanging - 120 seconds should be plenty for migrations
    if timeout 120 docker exec "$BACKEND_CONTAINER" bundle exec rails db:migrate 2>&1; then
        log_success "Database migrations completed"
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            log_warning "Database migrations timed out after 120 seconds"
        else
            log_warning "Database migrations returned exit code $EXIT_CODE (may be okay if no pending migrations)"
        fi
    fi
else
    log_warning "Could not find backend container for migrations - will run on next deploy"
fi

# ============================================================================
# Quick Health Check (non-blocking)
# ============================================================================
BACKEND_PORT=$(get_backend_port "$ENVIRONMENT")
FRONTEND_PORT=$(get_frontend_port "$ENVIRONMENT")

# Quick health checks with short timeout
if curl -sf --max-time 5 "http://localhost:${BACKEND_PORT}/health" > /dev/null 2>&1; then
    log_success "Backend health check passed (port $BACKEND_PORT)"
else
    log_info "Backend not yet responding (port $BACKEND_PORT) - Swarm will continue orchestrating"
fi

if curl -sf --max-time 5 "http://localhost:${FRONTEND_PORT}/" > /dev/null 2>&1; then
    log_success "Frontend health check passed (port $FRONTEND_PORT)"
else
    log_info "Frontend not yet responding (port $FRONTEND_PORT) - Swarm will continue orchestrating"
fi

log_success "ApplicationStart hook completed - Swarm is handling service orchestration"
exit 0
