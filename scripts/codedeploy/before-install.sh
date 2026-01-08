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

# Clean up old Docker resources (but preserve volumes for database)
log_info "Cleaning up old Docker resources..."
docker system prune -f 2>/dev/null || true

# Clean up old images (keep recent ones to allow rollback)
log_info "Cleaning up old Docker images..."
docker image prune -a --filter "until=168h" -f 2>/dev/null || true

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
