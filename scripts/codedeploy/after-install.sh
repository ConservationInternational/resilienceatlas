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
# Pull Docker Images from ECR
# ============================================================================
# Images are pre-built in CI/CD and pushed to Amazon ECR.
# This deployment script pulls those images and tags them for Swarm.
# ============================================================================
DEPLOY_TAG=$(date +%Y%m%d-%H%M%S)
export TAG="$DEPLOY_TAG"

# Verify ECR configuration
if [ -z "$ECR_REGISTRY" ] || [ -z "$BACKEND_IMAGE" ] || [ -z "$FRONTEND_IMAGE" ]; then
    log_error "ECR images not configured!"
    log_error "Required environment variables: ECR_REGISTRY, BACKEND_IMAGE, FRONTEND_IMAGE"
    log_error "ECR_REGISTRY=$ECR_REGISTRY"
    log_error "BACKEND_IMAGE=$BACKEND_IMAGE"
    log_error "FRONTEND_IMAGE=$FRONTEND_IMAGE"
    exit 1
fi

log_info "Pulling pre-built images from ECR"
log_info "Backend: $BACKEND_IMAGE"
log_info "Frontend: $FRONTEND_IMAGE"

# Log in to ECR
log_info "Logging in to Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION:-us-east-1}" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY" || {
    log_error "Failed to log in to ECR"
    exit 1
}
log_success "Logged in to ECR"

# Pull images in parallel for speed
log_info "Pulling images in parallel..."
docker pull "$BACKEND_IMAGE" &
BACKEND_PULL_PID=$!
docker pull "$FRONTEND_IMAGE" &
FRONTEND_PULL_PID=$!

# Wait for both pulls to complete
wait $BACKEND_PULL_PID || {
    log_error "Failed to pull backend image from ECR: $BACKEND_IMAGE"
    exit 1
}
wait $FRONTEND_PULL_PID || {
    log_error "Failed to pull frontend image from ECR: $FRONTEND_IMAGE"
    exit 1
}

log_success "ECR images pulled successfully"

# Tag images for local use by Docker Swarm
docker tag "$BACKEND_IMAGE" "${STACK_NAME}-backend:${DEPLOY_TAG}"
docker tag "$BACKEND_IMAGE" "${STACK_NAME}-backend:latest"
docker tag "$FRONTEND_IMAGE" "${STACK_NAME}-frontend:${DEPLOY_TAG}"
docker tag "$FRONTEND_IMAGE" "${STACK_NAME}-frontend:latest"

log_success "Images tagged for Swarm deployment"

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

# ============================================================================
# Ensure Storage Directories and Volumes Exist
# ============================================================================
# ActiveStorage needs persistent directories for uploaded images.
# These directories will be mounted as Docker volumes in the containers.
# ============================================================================
log_info "Ensuring storage directories exist for ActiveStorage..."

# Create storage directories if they don't exist on the host
# These may be needed for initial volume creation or legacy setups
STORAGE_BASE="/var/lib/docker/volumes"
if [ "$ENVIRONMENT" = "staging" ]; then
    STACK_PREFIX="resilienceatlas-staging_staging"
else
    STACK_PREFIX="resilienceatlas-production_production"
fi

# Ensure the volumes exist (Docker will create them, but let's make sure permissions are correct)
for volume_suffix in "backend_storage" "backend_public_storage"; do
    VOLUME_NAME="${STACK_PREFIX}_${volume_suffix}"
    VOLUME_PATH="${STORAGE_BASE}/${VOLUME_NAME}/_data"
    
    # Create volume directory if it doesn't exist (Docker may not have created it yet)
    if [ ! -d "$VOLUME_PATH" ]; then
        log_info "Creating volume directory: $VOLUME_PATH"
        mkdir -p "$VOLUME_PATH" 2>/dev/null || true
    fi
    
    # Set permissions (containers run as non-root user)
    if [ -d "$VOLUME_PATH" ]; then
        chmod 775 "$VOLUME_PATH" 2>/dev/null || true
        log_success "Storage volume ready: $VOLUME_NAME"
    fi
done

log_success "AfterInstall hook (Swarm mode) completed successfully"
exit 0
