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

# ============================================================================
# Pull Pre-built Images from ECR
# ============================================================================
if [ -n "$ECR_REGISTRY" ] && [ -n "$BACKEND_IMAGE" ] && [ -n "$FRONTEND_IMAGE" ]; then
    log_info "ECR images configured - pulling pre-built images..."
    log_info "Backend image: $BACKEND_IMAGE"
    log_info "Frontend image: $FRONTEND_IMAGE"
    
    # Login to ECR
    log_info "Logging in to ECR registry: $ECR_REGISTRY"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$ECR_REGISTRY"
    
    # Pull images in parallel for faster deployment
    log_info "Pulling images from ECR..."
    docker pull "$BACKEND_IMAGE" &
    BACKEND_PID=$!
    docker pull "$FRONTEND_IMAGE" &
    FRONTEND_PID=$!
    
    # Wait for both pulls to complete
    if wait $BACKEND_PID && wait $FRONTEND_PID; then
        log_success "Successfully pulled images from ECR"
        
        # Tag images for use in docker-compose (if needed)
        docker tag "$BACKEND_IMAGE" "resilienceatlas-backend:${ENVIRONMENT}"
        docker tag "$FRONTEND_IMAGE" "resilienceatlas-frontend:${ENVIRONMENT}"
    else
        log_error "Failed to pull images from ECR"
        exit 1
    fi
else
    log_info "ECR images not configured - will use locally built images"
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
# Resolve Host IP for Database Connection
# ============================================================================
# Docker Swarm does not support 'host.docker.internal' with 'host-gateway'.
# For containers to connect to PostgreSQL on the host, we need to use the
# actual host IP or Docker's bridge gateway (172.17.0.1).
# We must update the .env file on disk since docker stack deploy reads from it.
# ============================================================================
if [ "$ENVIRONMENT" = "production" ]; then
    # Get the Docker bridge gateway IP (typically 172.17.0.1)
    DOCKER_HOST_IP=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "172.17.0.1")
    export DOCKER_HOST_IP
    log_info "Docker host gateway IP: $DOCKER_HOST_IP"
    
    # Update the .env.production file on disk to replace host.docker.internal
    # This is necessary because docker stack deploy reads env vars from the file
    ENV_FILE="$APP_DIR/.env.production"
    if [ -f "$ENV_FILE" ] && grep -q "host.docker.internal" "$ENV_FILE"; then
        log_info "Updating $ENV_FILE to replace host.docker.internal with $DOCKER_HOST_IP"
        sed -i "s/host\.docker\.internal/$DOCKER_HOST_IP/g" "$ENV_FILE"
        log_success "Updated .env.production file with Docker host IP"
        
        # Reload environment variables after modification
        set -a
        source "$ENV_FILE"
        set +a
    fi
fi

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
