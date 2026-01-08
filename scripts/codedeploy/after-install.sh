#!/bin/bash
# ============================================================================
# AfterInstall Hook (Swarm Mode) - Configure application after files are deployed
# ============================================================================
# This script is executed after files are copied to the deployment location.
# It sets up the environment and prepares for Swarm deployment.
#
# This is the Swarm-mode version that enables zero-downtime deployments.
# ============================================================================

set -e

# Source common functions from our deployment directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "AfterInstall hook (Swarm mode) started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set application directory
APP_DIR=$(get_app_directory "$ENVIRONMENT")
STACK_NAME="resilienceatlas-${ENVIRONMENT}"

cd "$APP_DIR"
log_info "Working directory: $APP_DIR"
log_info "Stack name: $STACK_NAME"

# Load environment variables
ENV_FILE=$(get_env_file "$ENVIRONMENT")
DEPLOYED_ENV_FILE="$APP_DIR/.env.$ENVIRONMENT"

# Check for env file in deployment package first
if [ -f "$DEPLOYED_ENV_FILE" ]; then
    log_info "Found environment file from deployment package: $DEPLOYED_ENV_FILE"
    ENV_FILE="$DEPLOYED_ENV_FILE"
    log_success "Using environment file from GitHub Secrets"
elif [ -f "$ENV_FILE" ]; then
    log_info "Using existing environment file on server: $ENV_FILE"
else
    log_error "No environment file found!"
    log_error "Expected: $ENV_FILE"
    exit 1
fi

# Load the environment variables
log_info "Loading environment variables from $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

# Verify critical variables are set
if [ -z "$SECRET_KEY_BASE" ]; then
    log_error "SECRET_KEY_BASE is not set in $ENV_FILE"
    exit 1
fi
log_success "Environment variables loaded successfully"

# Set environment-specific variables
export RAILS_ENV="$ENVIRONMENT"
export NODE_ENV="production"

# ============================================================================
# Initialize Docker Swarm (if not already initialized)
# ============================================================================
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    log_info "Initializing Docker Swarm..."
    
    # Get the private IP for swarm advertising
    PRIVATE_IP=$(hostname -I | awk '{print $1}')
    
    docker swarm init --advertise-addr "$PRIVATE_IP" 2>/dev/null || {
        log_warning "Swarm init returned error, checking if already initialized..."
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            log_info "Swarm is now active"
        else
            log_error "Failed to initialize Docker Swarm"
            exit 1
        fi
    }
    
    log_success "Docker Swarm initialized"
else
    log_info "Docker Swarm already active"
fi

# ============================================================================
# Build Docker Images (with BuildKit for optimal caching)
# ============================================================================
# BuildKit provides:
#   - Parallel layer building
#   - Better cache management
#   - Inline cache metadata for faster subsequent builds
# ============================================================================
DEPLOY_TAG=$(date +%Y%m%d-%H%M%S)
export TAG="$DEPLOY_TAG"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

log_info "Building Docker images with tag: $DEPLOY_TAG (BuildKit enabled)"

# Build frontend with environment variables and cache optimization
log_info "Building frontend image..."
docker build -t "${STACK_NAME}-frontend:${DEPLOY_TAG}" \
    -t "${STACK_NAME}-frontend:latest" \
    --target production \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --cache-from "${STACK_NAME}-frontend:latest" \
    --build-arg NEXT_PUBLIC_API_HOST="${NEXT_PUBLIC_API_HOST:-}" \
    --build-arg NEXT_PUBLIC_GOOGLE_ANALYTICS="${NEXT_PUBLIC_GOOGLE_ANALYTICS:-}" \
    --build-arg NEXT_PUBLIC_TRANSIFEX_TOKEN="${NEXT_PUBLIC_TRANSIFEX_TOKEN:-}" \
    --build-arg NEXT_PUBLIC_TRANSIFEX_SECRET="${NEXT_PUBLIC_TRANSIFEX_SECRET:-}" \
    --build-arg NEXT_PUBLIC_GOOGLE_API_KEY="${NEXT_PUBLIC_GOOGLE_API_KEY:-}" \
    --build-arg NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN="${NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN:-}" \
    ./frontend

# Build backend with cache optimization
log_info "Building backend image..."
docker build -t "${STACK_NAME}-backend:${DEPLOY_TAG}" \
    -t "${STACK_NAME}-backend:latest" \
    --target production \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    --cache-from "${STACK_NAME}-backend:latest" \
    ./backend

log_success "Docker images built successfully"

# Save the tag for ApplicationStart hook
echo "$DEPLOY_TAG" > "$APP_DIR/.deploy_tag"

# ============================================================================
# Environment-specific pre-deployment setup
# ============================================================================
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Running staging-specific setup..."
    
    # For staging, we need to ensure the database volume exists
    # The database service will be started as part of the stack
    
    # Sync production database to staging (if configured)
    if [ -n "$PRODUCTION_DATABASE_URL" ] && [ -n "$SYNC_PRODUCTION_DB" ] && [ "$SYNC_PRODUCTION_DB" = "true" ]; then
        log_info "Database sync configured - will sync after stack deployment"
    fi
    
elif [ "$ENVIRONMENT" = "production" ]; then
    log_info "Running production-specific setup..."
    
    # Verify external database connectivity
    if [ -n "$PRODUCTION_DATABASE_URL" ]; then
        log_info "Testing production database connectivity..."
        
        DB_HOST=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
        DB_PORT=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
        
        if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ]; then
            if timeout 10 bash -c "echo > /dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
                log_success "Production database is reachable"
            else
                log_warning "Cannot reach production database at $DB_HOST:$DB_PORT"
            fi
        fi
    fi
fi

# Set correct permissions
log_info "Setting file permissions..."
chown -R ubuntu:ubuntu "$APP_DIR"
chmod +x "$APP_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$APP_DIR/scripts/codedeploy/"*.sh 2>/dev/null || true

log_success "AfterInstall hook (Swarm mode) completed successfully"
exit 0
