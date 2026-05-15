#!/bin/bash
# ============================================================================
# Swarm Rollback Script - Rollback services to previous version
# ============================================================================
# This script handles rolling back services to their previous version
# in case of deployment issues.
#
# Usage:
#   ./scripts/codedeploy/swarm-rollback.sh [staging|production] [service]
#
# Examples:
#   ./scripts/codedeploy/swarm-rollback.sh staging          # Rollback all services
#   ./scripts/codedeploy/swarm-rollback.sh production backend  # Rollback only backend
# ============================================================================

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Get environment
if [ -n "$1" ]; then
    ENVIRONMENT="$1"
else
    ENVIRONMENT=$(detect_environment)
fi

# Get optional service name
SERVICE_NAME="$2"

STACK_NAME="resilienceatlas-${ENVIRONMENT}"

log_info "Swarm rollback started for environment: $ENVIRONMENT"
log_info "Stack name: $STACK_NAME"

if [ -n "$SERVICE_NAME" ]; then
    # Rollback specific service
    FULL_SERVICE_NAME="${STACK_NAME}_${SERVICE_NAME}"
    log_info "Rolling back service: $FULL_SERVICE_NAME"
    
    docker service rollback "$FULL_SERVICE_NAME" || {
        log_error "Rollback failed for $FULL_SERVICE_NAME"
        exit 1
    }
    
    log_success "Rollback completed for $FULL_SERVICE_NAME"
else
    # Rollback all services
    log_info "Rolling back all services..."
    
    for SERVICE in backend frontend; do
        FULL_SERVICE_NAME="${STACK_NAME}_${SERVICE}"
        
        if docker service ls --filter "name=$FULL_SERVICE_NAME" --format "{{.Name}}" | grep -q "$FULL_SERVICE_NAME"; then
            log_info "Rolling back: $FULL_SERVICE_NAME"
            docker service rollback "$FULL_SERVICE_NAME" 2>/dev/null || {
                log_warning "Rollback skipped for $FULL_SERVICE_NAME (may not have previous version)"
            }
        else
            log_warning "Service not found: $FULL_SERVICE_NAME"
        fi
    done
    
    log_success "Rollback completed for all services"
fi

# Show current status
log_info "Current service status:"
docker stack services "$STACK_NAME"

log_info "Service tasks:"
docker stack ps "$STACK_NAME" --no-trunc 2>/dev/null | head -20

exit 0
