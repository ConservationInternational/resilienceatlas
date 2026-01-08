#!/bin/bash
# ============================================================================
# Swarm Deployment Script - Initialize and Deploy with Docker Swarm
# ============================================================================
# This script handles:
#   - Initializing Docker Swarm (if not already initialized)
#   - Building and tagging images for the stack
#   - Deploying/updating the stack with zero-downtime rolling updates
#   - Running database migrations after deployment
#
# Usage:
#   ./scripts/codedeploy/swarm-deploy.sh [staging|production]
#
# The script automatically detects the environment if not provided.
# ============================================================================

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Override environment if provided as argument
if [ -n "$1" ]; then
    ENVIRONMENT="$1"
else
    ENVIRONMENT=$(detect_environment)
fi

log_info "Swarm deployment started for environment: $ENVIRONMENT"

# Set variables based on environment
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
else
    log_error "Environment file not found: $ENV_FILE"
    exit 1
fi

# Generate a unique tag for this deployment
DEPLOY_TAG=$(date +%Y%m%d-%H%M%S)
export TAG="$DEPLOY_TAG"
log_info "Deployment tag: $DEPLOY_TAG"

# ============================================================================
# Initialize Docker Swarm (if not already initialized)
# ============================================================================
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    log_info "Initializing Docker Swarm..."
    
    # Get the private IP for swarm advertising
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    
    docker swarm init --advertise-addr "$PRIVATE_IP" 2>/dev/null || {
        log_warning "Swarm init failed, may already be initialized"
    }
    
    log_success "Docker Swarm initialized"
else
    log_info "Docker Swarm already active"
fi

# ============================================================================
# Build Docker Images
# ============================================================================
log_info "Building Docker images with tag: $DEPLOY_TAG"

# Build frontend
log_info "Building frontend image..."
docker build -t "${STACK_NAME}-frontend:${DEPLOY_TAG}" \
    -t "${STACK_NAME}-frontend:latest" \
    --target production \
    --build-arg NEXT_PUBLIC_API_HOST="${NEXT_PUBLIC_API_HOST:-}" \
    --build-arg NEXT_PUBLIC_GOOGLE_ANALYTICS="${NEXT_PUBLIC_GOOGLE_ANALYTICS:-}" \
    --build-arg NEXT_PUBLIC_TRANSIFEX_TOKEN="${NEXT_PUBLIC_TRANSIFEX_TOKEN:-}" \
    --build-arg NEXT_PUBLIC_TRANSIFEX_SECRET="${NEXT_PUBLIC_TRANSIFEX_SECRET:-}" \
    --build-arg NEXT_PUBLIC_GOOGLE_API_KEY="${NEXT_PUBLIC_GOOGLE_API_KEY:-}" \
    --build-arg NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN="${NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN:-}" \
    ./frontend

# Build backend
log_info "Building backend image..."
docker build -t "${STACK_NAME}-backend:${DEPLOY_TAG}" \
    -t "${STACK_NAME}-backend:latest" \
    --target production \
    ./backend

log_success "Docker images built successfully"

# ============================================================================
# Deploy Stack
# ============================================================================
log_info "Deploying stack: $STACK_NAME"

# Check if stack already exists
EXISTING_SERVICES=$(docker stack services "$STACK_NAME" 2>/dev/null | wc -l || echo "0")

if [ "$EXISTING_SERVICES" -gt 1 ]; then
    log_info "Updating existing stack with rolling update..."
    
    # Update each service individually to ensure proper rollout
    log_info "Updating backend service..."
    docker service update \
        --image "${STACK_NAME}-backend:${DEPLOY_TAG}" \
        --update-parallelism 1 \
        --update-delay 30s \
        --update-order start-first \
        --update-failure-action rollback \
        "${STACK_NAME}_backend" || {
            log_error "Backend update failed"
            exit 1
        }
    
    log_info "Updating frontend service..."
    docker service update \
        --image "${STACK_NAME}-frontend:${DEPLOY_TAG}" \
        --update-parallelism 1 \
        --update-delay 30s \
        --update-order start-first \
        --update-failure-action rollback \
        "${STACK_NAME}_frontend" || {
            log_error "Frontend update failed"
            exit 1
        }
else
    log_info "Deploying new stack..."
    docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME"
fi

log_success "Stack deployment initiated"

# ============================================================================
# Wait for Services to be Ready
# ============================================================================
log_info "Waiting for services to be ready..."

MAX_WAIT=300
WAIT_TIME=0
INTERVAL=10

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check backend replicas
    BACKEND_REPLICAS=$(docker service ls --filter "name=${STACK_NAME}_backend" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    BACKEND_CURRENT=$(echo "$BACKEND_REPLICAS" | cut -d'/' -f1)
    BACKEND_DESIRED=$(echo "$BACKEND_REPLICAS" | cut -d'/' -f2)
    
    # Check frontend replicas
    FRONTEND_REPLICAS=$(docker service ls --filter "name=${STACK_NAME}_frontend" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    FRONTEND_CURRENT=$(echo "$FRONTEND_REPLICAS" | cut -d'/' -f1)
    FRONTEND_DESIRED=$(echo "$FRONTEND_REPLICAS" | cut -d'/' -f2)
    
    log_info "Service status: backend=$BACKEND_REPLICAS, frontend=$FRONTEND_REPLICAS (${WAIT_TIME}s/${MAX_WAIT}s)"
    
    # Check if all services are fully deployed
    if [ "$BACKEND_CURRENT" = "$BACKEND_DESIRED" ] && [ "$BACKEND_DESIRED" != "0" ] && \
       [ "$FRONTEND_CURRENT" = "$FRONTEND_DESIRED" ] && [ "$FRONTEND_DESIRED" != "0" ]; then
        log_success "All services are running"
        break
    fi
    
    sleep $INTERVAL
    WAIT_TIME=$((WAIT_TIME + INTERVAL))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log_warning "Services may not be fully ready after $MAX_WAIT seconds"
    log_info "Current service status:"
    docker stack services "$STACK_NAME"
fi

# ============================================================================
# Run Database Migrations
# ============================================================================
log_info "Running database migrations..."

# Find a running backend container
BACKEND_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_backend" --format "{{.ID}}" | head -1)

if [ -n "$BACKEND_CONTAINER" ]; then
    if docker exec "$BACKEND_CONTAINER" bundle exec rails db:migrate 2>/dev/null; then
        log_success "Database migrations completed"
    else
        log_warning "Database migrations failed or not applicable"
    fi
else
    log_warning "Could not find backend container for migrations"
fi

# ============================================================================
# Final Status
# ============================================================================
log_info "Deployment complete. Stack status:"
docker stack services "$STACK_NAME"

log_info "Service tasks:"
docker stack ps "$STACK_NAME" --no-trunc 2>/dev/null | head -20

log_success "Swarm deployment completed successfully for $ENVIRONMENT"
exit 0
