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
# Docker Cleanup Strategy
# ============================================================================
# Since all images are stored on ECR, we can safely clean up local Docker
# resources. Images are always pulled fresh from ECR during deployment.
#
# Cleanup levels:
#   1. Always: Remove stopped containers, dangling images, unused networks
#   2. Always: Remove images older than 7 days (they're on ECR anyway)
#   3. If disk > 70%: Aggressive cleanup - remove all unused images
#   4. If disk > 85%: Emergency cleanup - remove everything including cache
# ============================================================================

log_info "Checking Docker disk usage before cleanup..."
DISK_USAGE=$(df /var/lib/docker 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
log_info "Current Docker disk usage: ${DISK_USAGE:-unknown}%"

# Show Docker disk usage breakdown
log_info "Docker disk usage breakdown:"
docker system df 2>/dev/null || true

# Level 1: Basic cleanup (always run)
log_info "Removing stopped containers..."
docker container prune -f 2>/dev/null || true

log_info "Removing dangling images..."
docker image prune -f 2>/dev/null || true

log_info "Removing unused networks..."
docker network prune -f 2>/dev/null || true

# Level 2: Remove old images (always run - images are on ECR)
log_info "Removing Docker images older than 7 days..."
docker image prune -a --filter "until=168h" -f 2>/dev/null || true

# Level 3: Aggressive cleanup if disk usage > 70%
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 70 ]; then
    log_warning "Disk usage is ${DISK_USAGE}% (>70%). Running aggressive cleanup..."
    
    # Remove ALL unused images (not just old ones)
    log_info "Removing all unused Docker images..."
    docker image prune -a -f 2>/dev/null || true
    
    # Remove unused volumes
    log_info "Removing unused Docker volumes..."
    docker volume prune -f 2>/dev/null || true
    
    # Clean up build cache older than 7 days
    log_info "Cleaning up Docker build cache older than 7 days..."
    docker builder prune --filter "until=168h" -f 2>/dev/null || true
fi

# Level 4: Emergency cleanup if disk usage > 85%
if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -gt 85 ]; then
    log_warning "Disk usage is ${DISK_USAGE}% (>85%). Running EMERGENCY cleanup..."
    
    # Nuclear option: remove everything unused including all build cache
    log_info "Removing ALL unused Docker resources including build cache..."
    docker system prune -a --volumes -f 2>/dev/null || true
    
    # Also clean containerd content store (can accumulate failed pulls)
    if [ -d "/var/lib/containerd/io.containerd.content.v1.content/ingest" ]; then
        log_info "Cleaning up containerd ingest directory..."
        rm -rf /var/lib/containerd/io.containerd.content.v1.content/ingest/* 2>/dev/null || true
    fi
fi

# Report final disk usage
DISK_USAGE_AFTER=$(df /var/lib/docker 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
log_info "Docker disk usage after cleanup: ${DISK_USAGE_AFTER:-unknown}%"

if [ -n "$DISK_USAGE_AFTER" ] && [ "$DISK_USAGE_AFTER" -gt 90 ]; then
    log_error "Disk usage still critical (${DISK_USAGE_AFTER}%). Deployment may fail."
    log_error "Consider expanding the EBS volume or manual investigation."
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
