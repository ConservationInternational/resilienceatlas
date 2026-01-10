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

# NOTE: We intentionally do NOT use "set -e" here because:
# 1. We want to control error handling explicitly
# 2. We want to log useful debugging information before exiting
# 3. set -e can cause silent failures that are hard to debug

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! source "${SCRIPT_DIR}/common.sh"; then
    echo "[ERROR] Failed to source common.sh from ${SCRIPT_DIR}"
    exit 1
fi

log_info "ValidateService hook (Swarm mode) started"

# Detect environment
ENVIRONMENT=$(detect_environment)
if [ -z "$ENVIRONMENT" ]; then
    log_error "Failed to detect environment"
    exit 1
fi
log_info "Detected environment: $ENVIRONMENT"

# Set application directory and stack name
APP_DIR=$(get_app_directory "$ENVIRONMENT")
STACK_NAME="resilienceatlas-${ENVIRONMENT}"
if ! cd "$APP_DIR"; then
    log_error "Failed to change to directory: $APP_DIR"
    exit 1
fi

# Load environment variables
ENV_FILE=$(get_env_file "$ENVIRONMENT")
if [ -f "$ENV_FILE" ]; then
    log_info "Loading environment file: $ENV_FILE"
    set -a
    # shellcheck disable=SC1090
    if ! source "$ENV_FILE"; then
        log_warning "Failed to source environment file (continuing anyway)"
    fi
    set +a
else
    log_warning "Environment file not found: $ENV_FILE (continuing anyway)"
fi

# Get the appropriate ports
FRONTEND_PORT=$(get_frontend_port "$ENVIRONMENT")
BACKEND_PORT=$(get_backend_port "$ENVIRONMENT")

log_info "Stack name: $STACK_NAME"
log_info "Using ports - Frontend: $FRONTEND_PORT, Backend: $BACKEND_PORT"

# Verify connectivity before starting health checks
log_info "Testing port connectivity..."
log_info "netstat output for ports $FRONTEND_PORT and $BACKEND_PORT:"
netstat -tlnp 2>/dev/null | grep -E ":($FRONTEND_PORT|$BACKEND_PORT)" || log_warning "No listeners found on expected ports"

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
log_info "Frontend URL: http://localhost:${FRONTEND_PORT}"
ATTEMPT=1
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    log_info "Frontend health check attempt $ATTEMPT/$MAX_ATTEMPTS..."
    
    # Capture curl output for debugging
    # Force IPv4 (-4) because Swarm ingress routing mesh may not handle IPv6 correctly
    CURL_OUTPUT=$(curl -4 -f -s --max-time 10 --connect-timeout 5 -w "\nHTTP_CODE:%{http_code}" "http://localhost:${FRONTEND_PORT}" 2>&1)
    CURL_EXIT=$?
    
    if [ $CURL_EXIT -eq 0 ]; then
        log_success "Frontend health check passed"
        break
    else
        log_info "Frontend not ready yet (curl exit: $CURL_EXIT, response: $(echo "$CURL_OUTPUT" | tail -1))"
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
    
    # Force IPv4 (-4) because Swarm ingress routing mesh may not handle IPv6 correctly
    RESPONSE=$(curl -4 -s --max-time 10 --connect-timeout 5 -w "HTTP_CODE:%{http_code}" "http://localhost:${BACKEND_PORT}/health" 2>&1 || echo "FAILED")
    
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
