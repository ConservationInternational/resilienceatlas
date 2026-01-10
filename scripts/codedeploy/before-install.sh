#!/bin/bash
# ============================================================================
# BeforeInstall Hook - Prepare environment for new deployment
# ============================================================================
# This script is executed after ApplicationStop and before files are copied.
# It prepares the environment, installs dependencies, and cleans up old files.
#
# SINGLE-INSTANCE SUPPORT:
# The GitHub workflow modifies appspec.yml to deploy directly to:
#   - /opt/resilienceatlas-staging (for staging)
#   - /opt/resilienceatlas-production (for production)
# This prevents race conditions between simultaneous deployments.
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "BeforeInstall hook started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Environment-specific application directory
APP_DIR=$(get_app_directory "$ENVIRONMENT")
log_info "Application directory: $APP_DIR"

# Create application directory if it doesn't exist
if [ ! -d "$APP_DIR" ]; then
    log_info "Creating application directory: $APP_DIR"
    mkdir -p "$APP_DIR"
fi

# Set ownership
chown -R ubuntu:ubuntu "$APP_DIR"

# Ensure Docker is installed and running
log_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    log_info "Starting Docker service..."
    systemctl start docker
fi

# Ensure docker-compose is available
log_info "Checking Docker Compose installation..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Install PostgreSQL client if not present (needed for database sync on staging)
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Checking PostgreSQL client installation..."
    if ! command -v psql &> /dev/null; then
        log_info "Installing PostgreSQL client..."
        apt-get update -qq
        apt-get install -y -qq postgresql-client-15 2>/dev/null || \
        apt-get install -y -qq postgresql-client 2>/dev/null
    fi
fi

# ============================================================================
# Docker Cleanup Strategy (Preserves Build Cache for Faster Builds)
# ============================================================================
# We want to:
#   - Keep build cache (speeds up subsequent builds significantly)
#   - Keep recent images (for rollback and layer sharing)
#   - Remove only stopped containers and dangling images
#   - Periodically clean old images to prevent disk bloat
# ============================================================================

log_info "Cleaning up Docker resources (preserving build cache)..."

# Remove stopped containers only (not build cache)
docker container prune -f 2>/dev/null || true

# Remove dangling images only (untagged, not used as cache)
docker image prune -f 2>/dev/null || true

# Remove images older than 14 days (keep recent for rollback + cache layers)
# Note: This only removes final images, not intermediate build cache layers
log_info "Cleaning up old Docker images (older than 14 days)..."
docker image prune -a --filter "until=336h" -f 2>/dev/null || true

# Clean up build cache older than 30 days (keep recent cache for fast builds)
log_info "Cleaning up old Docker build cache (older than 30 days)..."
docker builder prune --filter "until=720h" -f 2>/dev/null || true

# Check disk usage and warn if low
DISK_USAGE=$(df /var/lib/docker 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 85 ]; then
    log_warning "Docker disk usage is at ${DISK_USAGE}%. Consider manual cleanup."
    log_info "Run 'docker system prune -a' to free more space (will clear all cache)"
fi

# Backup current deployment (for rollback purposes)
if [ -d "$APP_DIR" ] && [ -f "$APP_DIR/docker-compose.yml" -o -f "$APP_DIR/docker-compose.staging.yml" ]; then
    BACKUP_DIR="/opt/resilienceatlas-backups/${ENVIRONMENT}"
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
    
    log_info "Creating deployment backup for $ENVIRONMENT: $BACKUP_NAME"
    mkdir -p "$BACKUP_DIR"
    
    # Save current commit SHA for rollback reference
    if [ -d "$APP_DIR/.git" ]; then
        cd "$APP_DIR"
        git rev-parse HEAD > "$BACKUP_DIR/$BACKUP_NAME.sha" 2>/dev/null || true
    fi
    
    # Keep only last 5 backups per environment
    cd "$BACKUP_DIR"
    ls -t *.sha 2>/dev/null | tail -n +6 | xargs -r rm -f
fi

# Create required directories
log_info "Creating required directories..."
mkdir -p "$APP_DIR/logs"
mkdir -p "$APP_DIR/tmp"
mkdir -p "/var/log/resilienceatlas-${ENVIRONMENT}"

# Set permissions
chown -R ubuntu:ubuntu "$APP_DIR"
chmod -R 755 "$APP_DIR"

log_success "BeforeInstall hook completed successfully"
exit 0
