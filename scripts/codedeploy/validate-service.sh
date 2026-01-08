#!/bin/bash
# ============================================================================
# ValidateService Hook - Validate application is running correctly
# ============================================================================
# This script is executed after ApplicationStart to validate the deployment.
# It performs health checks on all services.
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "ValidateService hook started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set application directory
APP_DIR=$(get_app_directory "$ENVIRONMENT")
cd "$APP_DIR"

# Get the appropriate docker-compose file
COMPOSE_FILE=$(get_compose_file "$ENVIRONMENT")

# Health check configuration
MAX_ATTEMPTS=30
ATTEMPT=1
WAIT_TIME=10

# Health check for frontend
log_info "Performing frontend health check..."
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Frontend health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    if curl -f -s http://localhost:3000 >/dev/null 2>&1; then
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
    log_info "Frontend container logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail 50 frontend || true
    exit 1
fi

# Health check for backend
log_info "Performing backend health check..."
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Backend health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    RESPONSE=$(curl -s -w "HTTP_CODE:%{http_code}" http://localhost:3001/health 2>&1 || echo "FAILED")
    
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
    log_info "Backend container logs:"
    docker compose -f "$COMPOSE_FILE" logs --tail 50 backend || true
    exit 1
fi

# Database health check (staging only - production uses external DB)
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Performing database health check..."
    ATTEMPT=1
    while [ $ATTEMPT -le 10 ]; do
        if docker compose -f "$COMPOSE_FILE" exec -T database pg_isready -U postgres >/dev/null 2>&1; then
            log_success "Database health check passed"
            break
        else
            log_info "Database not ready yet..."
        fi
        
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
    done
    
    if [ $ATTEMPT -gt 10 ]; then
        log_warning "Database health check failed, but continuing (may affect application functionality)"
    fi
fi

# Show final status
log_info "Final container status:"
docker compose -f "$COMPOSE_FILE" ps

# Calculate and log deployment info
log_success "Deployment validation completed successfully!"
log_success "Environment: $ENVIRONMENT"

if [ "$ENVIRONMENT" = "staging" ]; then
    log_success "Application available at: https://staging.resilienceatlas.org"
else
    log_success "Application available at: https://resilienceatlas.org"
fi

exit 0
