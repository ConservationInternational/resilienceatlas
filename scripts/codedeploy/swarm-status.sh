#!/bin/bash
# ============================================================================
# Swarm Status Script - Show status of Swarm services
# ============================================================================
# This script displays the current status of all Swarm services and their tasks.
#
# Usage:
#   ./scripts/codedeploy/swarm-status.sh [staging|production]
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

STACK_NAME="resilienceatlas-${ENVIRONMENT}"

echo ""
log_info "=== Docker Swarm Status for $ENVIRONMENT ==="
echo ""

# Check if swarm is active
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    log_error "Docker Swarm is not active"
    exit 1
fi

# Show node info
log_info "Swarm Node Info:"
docker node ls
echo ""

# Show stack services
log_info "Stack Services ($STACK_NAME):"
docker stack services "$STACK_NAME" 2>/dev/null || {
    log_warning "Stack not found: $STACK_NAME"
    exit 0
}
echo ""

# Show service tasks
log_info "Service Tasks:"
docker stack ps "$STACK_NAME" --no-trunc 2>/dev/null | head -30
echo ""

# Show container health for each service
log_info "Container Health:"
for SERVICE in backend frontend database; do
    FULL_SERVICE_NAME="${STACK_NAME}_${SERVICE}"
    
    CONTAINERS=$(docker ps --filter "name=${FULL_SERVICE_NAME}" --format "{{.ID}}: {{.Status}}" 2>/dev/null)
    
    if [ -n "$CONTAINERS" ]; then
        echo "  $SERVICE:"
        echo "$CONTAINERS" | while read line; do
            echo "    - $line"
        done
    fi
done
echo ""

# Show recent logs (last 10 lines per service)
log_info "Recent Logs (last 5 lines per service):"
for SERVICE in backend frontend; do
    FULL_SERVICE_NAME="${STACK_NAME}_${SERVICE}"
    
    if docker service ls --filter "name=$FULL_SERVICE_NAME" --format "{{.Name}}" | grep -q "$FULL_SERVICE_NAME"; then
        echo ""
        echo "  === $SERVICE ==="
        docker service logs "$FULL_SERVICE_NAME" --tail 5 2>/dev/null || echo "  (no logs available)"
    fi
done
echo ""

# Show resource usage
log_info "Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | grep "$STACK_NAME" || echo "  (no containers running)"
echo ""

log_success "Status check complete"
exit 0
