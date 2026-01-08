#!/bin/bash
# ============================================================================
# ApplicationStop Hook - Stop existing application before new deployment
# ============================================================================
# This script is executed when CodeDeploy begins a new deployment.
# It gracefully stops any running application containers.
#
# SINGLE-INSTANCE SUPPORT: Only stops containers for THIS environment,
# leaving the other environment running.
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "ApplicationStop hook started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set application directory (environment-specific)
APP_DIR=$(get_app_directory "$ENVIRONMENT")
PROJECT_NAME=$(get_project_name "$ENVIRONMENT")

# Check if application directory exists
if [ ! -d "$APP_DIR" ]; then
    log_warning "Application directory does not exist: $APP_DIR"
    log_info "Skipping application stop (likely first deployment)"
    exit 0
fi

cd "$APP_DIR"

# Get the appropriate docker-compose file
COMPOSE_FILE=$(get_compose_file "$ENVIRONMENT")

# Check if docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    log_warning "Docker Compose file not found: $COMPOSE_FILE"
    log_info "Skipping application stop"
    exit 0
fi

# Stop existing containers gracefully using project name
# This ensures we only stop THIS environment's containers
log_info "Stopping existing containers for project: $PROJECT_NAME"

# For staging, keep the database running to preserve data during deployment
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Staging environment: Stopping frontend and backend only (preserving database)"
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" stop frontend backend 2>/dev/null || true
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" rm -f frontend backend 2>/dev/null || true
else
    log_info "Production environment: Stopping all application containers"
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" down 2>/dev/null || true
fi

# Wait for containers to stop
sleep 5

log_success "ApplicationStop hook completed successfully"
exit 0
