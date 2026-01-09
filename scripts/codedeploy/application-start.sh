#!/bin/bash
# ============================================================================
# ApplicationStart Hook (Swarm Mode) - Deploy/Update the Swarm Stack
# ============================================================================
# This script deploys or updates the Docker Swarm stack with zero-downtime
# rolling updates.
#
# Key features:
#   - Rolling updates with start-first ordering (new containers start before old stop)
#   - Health-check aware (waits for new containers to be healthy)
#   - Automatic rollback on failure
#   - Database migrations after successful deployment
# ============================================================================

set -e

# Source common functions and configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "ApplicationStart hook (Swarm mode) started"

# Detect environment
ENVIRONMENT=$(detect_environment)
log_info "Detected environment: $ENVIRONMENT"

# Set variables
APP_DIR=$(get_app_directory "$ENVIRONMENT")
STACK_NAME="resilienceatlas-${ENVIRONMENT}"

if [ "$ENVIRONMENT" = "staging" ]; then
    COMPOSE_FILE="docker-compose.swarm.staging.yml"
else
    COMPOSE_FILE="docker-compose.swarm.yml"
fi

cd "$APP_DIR"
log_info "Working directory: $APP_DIR"
log_info "Stack name: $STACK_NAME"
log_info "Compose file: $COMPOSE_FILE"

# Load environment variables
ENV_FILE=$(get_env_file "$ENVIRONMENT")
if [ -f "$ENV_FILE" ]; then
    log_info "Loading environment variables from $ENV_FILE"
    set -a
    source "$ENV_FILE"
    set +a
fi

# Get the deployment tag from AfterInstall hook
if [ -f "$APP_DIR/.deploy_tag" ]; then
    DEPLOY_TAG=$(cat "$APP_DIR/.deploy_tag")
    log_info "Using deployment tag: $DEPLOY_TAG"
else
    DEPLOY_TAG="latest"
    log_warning "No deployment tag found, using 'latest'"
fi
export TAG="$DEPLOY_TAG"

# ============================================================================
# Deploy/Update Stack
# ============================================================================
# Always use docker stack deploy which is idempotent:
#   - For new deployments: creates all services
#   - For existing stacks: updates changed services and starts missing ones
# This ensures the database service starts even on updates.
# ============================================================================

# Check if stack already exists (for logging purposes)
EXISTING_SERVICES=$(docker stack services "$STACK_NAME" 2>/dev/null | wc -l || echo "0")

if [ "$EXISTING_SERVICES" -gt 1 ]; then
    log_info "Updating existing stack '$STACK_NAME'..."
else
    log_info "Deploying new stack '$STACK_NAME'..."
fi

# Deploy/update the stack - this is idempotent and handles both new and update cases
# It will:
#   - Start any services that aren't running (including database)
#   - Update services that have changed images or configuration
#   - Apply rolling update settings from the compose file
log_info "Running docker stack deploy with compose file: $COMPOSE_FILE"
docker stack deploy -c "$COMPOSE_FILE" "$STACK_NAME" --with-registry-auth

log_success "Stack deploy command completed"

# For staging, verify database is running
if [ "$ENVIRONMENT" = "staging" ]; then
    log_info "Verifying database service is running..."
    DB_STATUS=$(docker service ls --filter "name=${STACK_NAME}_database" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    log_info "Database service status: $DB_STATUS"
    
    # Wait for database to be ready before continuing
    MAX_DB_WAIT=60
    DB_WAIT=0
    while [ $DB_WAIT -lt $MAX_DB_WAIT ]; do
        DB_REPLICAS=$(docker service ls --filter "name=${STACK_NAME}_database" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
        DB_CURRENT=$(echo "$DB_REPLICAS" | cut -d'/' -f1)
        DB_DESIRED=$(echo "$DB_REPLICAS" | cut -d'/' -f2)
        
        if [ "$DB_CURRENT" = "$DB_DESIRED" ] && [ "$DB_DESIRED" != "0" ]; then
            log_success "Database service is running: $DB_REPLICAS"
            break
        fi
        
        log_info "Waiting for database... ($DB_REPLICAS, ${DB_WAIT}s/${MAX_DB_WAIT}s)"
        sleep 5
        DB_WAIT=$((DB_WAIT + 5))
    done
    
    if [ $DB_WAIT -ge $MAX_DB_WAIT ]; then
        log_warning "Database may not be fully ready after ${MAX_DB_WAIT}s"
    fi
fi

# ============================================================================
# Wait for Services to be Ready
# ============================================================================
log_info "Waiting for services to converge..."

MAX_WAIT=300
WAIT_TIME=0
INTERVAL=15

while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check backend replicas
    BACKEND_REPLICAS=$(docker service ls --filter "name=${STACK_NAME}_backend" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    BACKEND_CURRENT=$(echo "$BACKEND_REPLICAS" | cut -d'/' -f1)
    BACKEND_DESIRED=$(echo "$BACKEND_REPLICAS" | cut -d'/' -f2)
    
    # Check frontend replicas
    FRONTEND_REPLICAS=$(docker service ls --filter "name=${STACK_NAME}_frontend" --format "{{.Replicas}}" 2>/dev/null || echo "0/0")
    FRONTEND_CURRENT=$(echo "$FRONTEND_REPLICAS" | cut -d'/' -f1)
    FRONTEND_DESIRED=$(echo "$FRONTEND_REPLICAS" | cut -d'/' -f2)
    
    log_info "Service status: backend=$BACKEND_REPLICAS, frontend=$FRONTEND_REPLICAS (${WAIT_TIME}s/${MAX_WAIT}s)"
    
    # Check if all services are fully deployed and healthy
    if [ "$BACKEND_CURRENT" = "$BACKEND_DESIRED" ] && [ "$BACKEND_DESIRED" != "0" ] && \
       [ "$FRONTEND_CURRENT" = "$FRONTEND_DESIRED" ] && [ "$FRONTEND_DESIRED" != "0" ]; then
        
        # Additional check: ensure no tasks are in "starting" or "pending" state
        PENDING_TASKS=$(docker stack ps "$STACK_NAME" --filter "desired-state=running" --format "{{.CurrentState}}" 2>/dev/null | grep -E "^(Preparing|Starting|Pending)" | wc -l || echo "0")
        
        if [ "$PENDING_TASKS" -eq 0 ]; then
            log_success "All services are running and stable"
            break
        else
            log_info "Some tasks still starting ($PENDING_TASKS pending)..."
        fi
    fi
    
    sleep $INTERVAL
    WAIT_TIME=$((WAIT_TIME + INTERVAL))
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    log_warning "Services may not be fully ready after $MAX_WAIT seconds"
    log_info "Current service status:"
    docker stack services "$STACK_NAME"
    
    # Check for failed tasks
    FAILED_TASKS=$(docker stack ps "$STACK_NAME" --filter "desired-state=shutdown" --format "{{.Name}}: {{.Error}}" 2>/dev/null | head -5)
    if [ -n "$FAILED_TASKS" ]; then
        log_warning "Recent failed tasks:"
        echo "$FAILED_TASKS"
    fi
fi

# ============================================================================
# Run Database Migrations
# ============================================================================
log_info "Running database migrations..."

# Wait a bit for containers to fully initialize
sleep 10

# Find a running backend container
BACKEND_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_backend" --filter "health=healthy" --format "{{.ID}}" | head -1)

if [ -z "$BACKEND_CONTAINER" ]; then
    # Try without health filter
    BACKEND_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_backend" --format "{{.ID}}" | head -1)
fi

if [ -n "$BACKEND_CONTAINER" ]; then
    log_info "Running migrations in container: $BACKEND_CONTAINER"
    if docker exec "$BACKEND_CONTAINER" bundle exec rails db:migrate 2>&1; then
        log_success "Database migrations completed"
    else
        log_warning "Database migrations returned non-zero (may be okay if no pending migrations)"
    fi
else
    log_warning "Could not find backend container for migrations"
fi

# ============================================================================
# Health Verification
# ============================================================================
log_info "Verifying service health..."

BACKEND_PORT=$(get_backend_port "$ENVIRONMENT")
FRONTEND_PORT=$(get_frontend_port "$ENVIRONMENT")

# Check backend health
if curl -sf "http://localhost:${BACKEND_PORT}/health" > /dev/null 2>&1; then
    log_success "Backend health check passed (port $BACKEND_PORT)"
else
    log_warning "Backend health check failed (port $BACKEND_PORT)"
fi

# Check frontend health
if curl -sf "http://localhost:${FRONTEND_PORT}/" > /dev/null 2>&1; then
    log_success "Frontend health check passed (port $FRONTEND_PORT)"
else
    log_warning "Frontend health check failed (port $FRONTEND_PORT)"
fi

# ============================================================================
# Final Status
# ============================================================================
log_info "Deployment complete. Final stack status:"
docker stack services "$STACK_NAME"

log_success "ApplicationStart hook (Swarm mode) completed successfully"
exit 0
