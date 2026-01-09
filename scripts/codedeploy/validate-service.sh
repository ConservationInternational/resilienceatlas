#!/bin/bash
# ============================================================================
# ValidateService Hook (Swarm Mode) - Validate application is running correctly
# ============================================================================
# This script is executed after ApplicationStart to validate the deployment.
# It performs health checks on all services using Docker Swarm commands.
#
# SINGLE-INSTANCE SUPPORT: Uses environment-specific ports for health checks.
#   Production: Frontend=3000, Backend=3001
#   Staging:    Frontend=4000, Backend=4001
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "ValidateService hook (Swarm mode) started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set application directory and stack name
APP_DIR=$(get_app_directory "$ENVIRONMENT")
STACK_NAME="resilienceatlas-${ENVIRONMENT}"
cd "$APP_DIR"

# Load environment variables
ENV_FILE=$(get_env_file "$ENVIRONMENT")
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Get the appropriate ports
FRONTEND_PORT=$(get_frontend_port "$ENVIRONMENT")
BACKEND_PORT=$(get_backend_port "$ENVIRONMENT")

log_info "Stack name: $STACK_NAME"
log_info "Using ports - Frontend: $FRONTEND_PORT, Backend: $BACKEND_PORT"

# ============================================================================
# Verify Swarm Services are Running
# ============================================================================
log_info "Verifying Swarm services..."

# Check service status
log_info "Current stack services:"
docker stack services "$STACK_NAME" 2>/dev/null || {
    log_error "Failed to get stack services. Stack may not be deployed."
    exit 1
}

# Health check configuration - reduced for faster deployment
# Swarm continues orchestrating even after this script exits
MAX_ATTEMPTS=12
WAIT_TIME=5

# ============================================================================
# Frontend Health Check
# ============================================================================
log_info "Performing frontend health check..."
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Frontend health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    if curl -f -s "http://localhost:${FRONTEND_PORT}" >/dev/null 2>&1; then
        log_success "Frontend health check passed"
        break
    else
        log_info "Frontend not ready yet..."
    fi
    
    sleep $WAIT_TIME
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    log_error "Frontend health check failed after $MAX_ATTEMPTS attempts"
    log_info "Frontend service status:"
    docker service ps "${STACK_NAME}_frontend" --no-trunc 2>/dev/null || true
    log_info "Frontend service logs (last 30 lines):"
    docker service logs "${STACK_NAME}_frontend" --tail 30 2>/dev/null || true
    exit 1
fi

# ============================================================================
# Backend Health Check
# ============================================================================
log_info "Performing backend health check..."
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Backend health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" "http://localhost:${BACKEND_PORT}/health" 2>&1 || echo "FAILED")
    
    if echo "$RESPONSE" | grep -q "HTTP_CODE:200"; then
        log_success "Backend health check passed"
        break
    else
        log_info "Backend not ready yet. Response: $RESPONSE"
    fi
    
    sleep $WAIT_TIME
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
    log_error "Backend health check failed after $MAX_ATTEMPTS attempts"
    log_info "Backend service status:"
    docker service ps "${STACK_NAME}_backend" --no-trunc 2>/dev/null || true
    log_info "Backend service logs (last 30 lines):"
    docker service logs "${STACK_NAME}_backend" --tail 30 2>/dev/null || true
    exit 1
fi

# ============================================================================
# Database Health Check (Staging Only)
# ============================================================================
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Performing database health check..."
    ATTEMPT=1
    while [ $ATTEMPT -le 10 ]; do
        # Check database service is running
        DB_STATUS=$(docker service ls --filter "name=${STACK_NAME}_database" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
        DB_CURRENT=$(echo "$DB_STATUS" | cut -d'/' -f1)
        DB_DESIRED=$(echo "$DB_STATUS" | cut -d'/' -f2)
        
        if [ "$DB_CURRENT" = "$DB_DESIRED" ] && [ "$DB_DESIRED" != "0" ]; then
            # Find a database container and check pg_isready
            DB_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_database" --format "{{.ID}}" | head -1)
            if [ -n "$DB_CONTAINER" ]; then
                if docker exec "$DB_CONTAINER" pg_isready -U postgres >/dev/null 2>&1; then
                    log_success "Database health check passed"
                    break
                fi
            fi
        fi
        
        log_info "Database not ready yet (status: $DB_STATUS)..."
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
    done
    
    if [ $ATTEMPT -gt 10 ]; then
        log_warning "Database health check failed, but continuing (may affect application functionality)"
        log_info "Database service status:"
        docker service ps "${STACK_NAME}_database" --no-trunc 2>/dev/null || true
    fi
fi

# ============================================================================
# Final Status
# ============================================================================
log_info "Final stack status:"
docker stack services "$STACK_NAME"

log_info "Stack tasks:"
docker stack ps "$STACK_NAME" --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}\t{{.Error}}" 2>/dev/null | head -20

log_success "Deployment validation completed successfully!"
log_success "Environment: $ENVIRONMENT"
log_success "Frontend port: $FRONTEND_PORT, Backend port: $BACKEND_PORT"

if [ "$ENVIRONMENT" = "staging" ]; then
    log_success "Application available at: https://staging.resilienceatlas.org"
else
    log_success "Application available at: https://resilienceatlas.org"
fi

exit 0
