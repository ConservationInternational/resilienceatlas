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
# For containers on the overlay network to connect to PostgreSQL on the host,
# we need to use the host's actual private IP (e.g. 172.31.x.x on AWS EC2),
# NOT the Docker bridge gateway (172.17.0.1) which is only reachable from
# containers on the default bridge network, not the Swarm overlay network.
# We must update the .env file on disk since docker stack deploy reads from it.
# ============================================================================
if [ "$ENVIRONMENT" = "production" ]; then
    # Get the host's actual private IP address (reachable from Swarm overlay network)
    # On AWS EC2, this is the instance's VPC private IP (e.g. 172.31.x.x or 10.x.x.x)
    DOCKER_HOST_IP=$(hostname -I | awk '{print $1}')
    
    # Fallback: if hostname -I fails, try to get the IP from the default route interface
    if [ -z "$DOCKER_HOST_IP" ]; then
        DOCKER_HOST_IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
    fi
    
    # Final fallback to bridge gateway (less reliable for Swarm overlay)
    if [ -z "$DOCKER_HOST_IP" ]; then
        DOCKER_HOST_IP=$(docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "172.17.0.1")
        log_warning "Could not determine host private IP, falling back to Docker bridge gateway: $DOCKER_HOST_IP"
    fi
    
    export DOCKER_HOST_IP
    log_info "Host IP for database connection: $DOCKER_HOST_IP"
    
    # Update the .env.production file on disk to replace host.docker.internal
    # or any previously substituted IP with the current host IP
    ENV_FILE="$APP_DIR/.env.production"
    if [ -f "$ENV_FILE" ]; then
        if grep -q "host.docker.internal" "$ENV_FILE"; then
            log_info "Updating $ENV_FILE to replace host.docker.internal with $DOCKER_HOST_IP"
            sed -i "s/host\.docker\.internal/$DOCKER_HOST_IP/g" "$ENV_FILE"
            log_success "Updated .env.production file with host IP: $DOCKER_HOST_IP"
        elif grep -qE "@172\.17\." "$ENV_FILE"; then
            # Fix previously deployed configs that used the wrong bridge gateway IP
            log_info "Updating $ENV_FILE to replace Docker bridge IP (172.17.x.x) with host IP $DOCKER_HOST_IP"
            sed -i "s/@172\.17\.[0-9]*\.[0-9]*:/@$DOCKER_HOST_IP:/g" "$ENV_FILE"
            log_success "Updated .env.production file with correct host IP: $DOCKER_HOST_IP"
        fi
        
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

# Pre-pull the database image for staging deployments.
# Unlike backend/frontend images (stored on ECR), the database image comes from
# ghcr.io and is not pulled by the ECR pull step. The before-install.sh cleanup
# may have pruned it (images older than 7 days are removed), so we must ensure
# it's available locally before docker stack deploy tries to start the service.
if [ "$ENVIRONMENT" = "staging" ]; then
    DB_IMAGE=$(grep -E '^\s+image:' "$COMPOSE_FILE" | head -1 | awk '{print $2}')
    if [ -n "$DB_IMAGE" ]; then
        log_info "Pre-pulling database image: $DB_IMAGE"
        docker pull "$DB_IMAGE" || log_warning "Failed to pull database image (may already be cached)"
    fi
fi

log_info "Running docker stack deploy with compose file: $COMPOSE_FILE"

# Build the custom Martin image locally (adds curl for health checks)
# The Martin base image is minimal and has no HTTP client, so we extend it
log_info "Building custom Martin image with health check support..."
if docker build -t resilienceatlas-martin:latest -f docker/martin.Dockerfile docker/; then
    log_success "Martin image built successfully"
else
    log_warning "Failed to build custom Martin image, stack will use upstream image"
fi

# ============================================================================
# Remove existing Swarm configs only if their content has changed
# ============================================================================
# Docker Swarm configs are immutable - content cannot be updated once created
# (only Labels can be changed). docker stack deploy exits non-zero if it tries
# to update a config whose content has changed.
#
# Strategy: compare the stored config content against the local file.
# - If unchanged: skip removal entirely (no downtime).
# - If changed:   scale the dependent service to 0, remove the config, then
#                 let docker stack deploy recreate it with the new content.
#                 This causes brief downtime for Martin only, not backend/frontend.
_update_swarm_config_if_changed() {
    local config_name="$1"   # full Swarm config name (e.g. resilienceatlas-staging_martin_config)
    local config_file="$2"   # path to the source file on disk
    local service_name="$3"  # Swarm service that mounts this config

    if ! docker config inspect "$config_name" >/dev/null 2>&1; then
        log_info "Config $config_name does not exist yet - will be created by stack deploy"
        return 0
    fi

    # Docker stores config data as base64. Compare against current file content.
    local existing_b64
    existing_b64=$(docker config inspect "$config_name" --format '{{json .Spec.Data}}' | tr -d '"')
    local current_b64
    current_b64=$(base64 < "$config_file" | tr -d '\n')

    if [ "$existing_b64" = "$current_b64" ]; then
        log_info "Config $config_name is unchanged - skipping removal"
        return 0
    fi

    log_info "Config $config_name has changed - scaling $service_name to 0 to allow config update..."
    docker service scale "${service_name}=0" 2>/dev/null || true
    sleep 5
    log_info "Removing outdated Swarm config: $config_name"
    docker config rm "$config_name" || log_warning "Could not remove config $config_name - stack deploy may fail"
}

_update_swarm_config_if_changed \
    "${STACK_NAME}_martin_config" \
    "docker/martin.yaml" \
    "${STACK_NAME}_martin"

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
# Database Migrations
# ============================================================================
# NOTE: Database migrations are handled by the backend container's entrypoint
# (bin/docker-entrypoint), which runs `rails db:migrate` before starting Puma.
# Running db:prepare here via `docker exec` caused a race condition:
#   - docker exec picks any running backend container (possibly the OLD one)
#   - db:prepare acquires the Rails advisory lock on the database
#   - the NEW container's entrypoint also tries db:migrate
#   - the new container blocks on the lock, can't finish before health check
#   - Swarm kills it after start_period + retries, tries again, same result
#   - After max_attempts, Swarm rolls back the entire update
#
# The entrypoint handles all migration cases. If the database volume is lost,
# a manual `rails db:prepare` can be run after deployment.
log_info "Database migrations will be handled by the backend container entrypoint"

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
