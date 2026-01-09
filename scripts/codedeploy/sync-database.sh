#!/bin/bash
# ============================================================================
# Database Sync Script - Copy production database to staging
# ============================================================================
# This script copies the production PostgreSQL database to the staging
# Docker container. It is called during staging deployments when
# SYNC_PRODUCTION_DB=true is set.
# ============================================================================

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

log_info "Starting production database sync to staging..."

# Set application directory - use staging-specific path
APP_DIR="/opt/resilienceatlas-staging"
cd "$APP_DIR"

# Compose file for staging
COMPOSE_FILE="docker-compose.staging.yml"
PROJECT_NAME="resilienceatlas-staging"

# Load environment variables
if [ -f "$APP_DIR/.env.staging" ]; then
    set -a
    source "$APP_DIR/.env.staging"
    set +a
fi

# Validate required environment variables
if [ -z "$PRODUCTION_DATABASE_URL" ]; then
    log_error "PRODUCTION_DATABASE_URL is not set"
    log_error "Please set PRODUCTION_DATABASE_URL in .env.staging to sync production data"
    exit 1
fi

# Parse production database URL
# Format: postgresql://username:password@host:port/database
PROD_DB_USER=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
PROD_DB_PASS=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
PROD_DB_HOST=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*@\([^:]*\):.*/\1/p')
PROD_DB_PORT=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
PROD_DB_NAME=$(echo "$PRODUCTION_DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

# Set default port if not specified
PROD_DB_PORT=${PROD_DB_PORT:-5432}

log_info "Production database: $PROD_DB_HOST:$PROD_DB_PORT/$PROD_DB_NAME"

# Test connection to production database
log_info "Testing production database connection..."
if ! PGPASSWORD="$PROD_DB_PASS" psql -h "$PROD_DB_HOST" -p "$PROD_DB_PORT" -U "$PROD_DB_USER" -d "$PROD_DB_NAME" -c "SELECT version();" > /dev/null 2>&1; then
    log_error "Cannot connect to production database"
    log_error "Please verify PRODUCTION_DATABASE_URL and network connectivity"
    exit 1
fi
log_success "Production database connection successful"

# Create temporary dump directory
DUMP_DIR="/tmp/db-sync-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DUMP_DIR"
DUMP_FILE="$DUMP_DIR/production_dump.sql"

# Tables to exclude data from (large or sensitive tables)
# NOTE: active_storage_blobs and active_storage_attachments are INCLUDED
# so that images for homepage, journeys, and sites are synced to staging
EXCLUDE_DATA_TABLES=(
    "action_text_rich_texts"
    "logs"
    "audit_logs"
    "versions"
    "sessions"
    "ahoy_visits"
    "ahoy_events"
)

# Build exclude table data arguments
EXCLUDE_ARGS=""
for table in "${EXCLUDE_DATA_TABLES[@]}"; do
    EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude-table-data=$table"
done

# Dump production database
log_info "Creating dump of production database..."
log_info "Excluding data from: ${EXCLUDE_DATA_TABLES[*]}"

PGPASSWORD="$PROD_DB_PASS" pg_dump \
    -h "$PROD_DB_HOST" \
    -p "$PROD_DB_PORT" \
    -U "$PROD_DB_USER" \
    -d "$PROD_DB_NAME" \
    --verbose \
    --no-owner \
    --no-privileges \
    --no-acl \
    $EXCLUDE_ARGS \
    > "$DUMP_FILE" 2>"$DUMP_DIR/dump.log"

# Check dump file
DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
log_success "Dump file created: $DUMP_SIZE"

if [ ! -s "$DUMP_FILE" ]; then
    log_error "Dump file is empty"
    cat "$DUMP_DIR/dump.log"
    exit 1
fi

# Ensure staging database container is running
log_info "Ensuring staging database container is running..."
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d database

# Wait for database to be ready
wait_for_database "$COMPOSE_FILE" "$PROJECT_NAME"

# Get staging database credentials
STAGING_DB_NAME="resilienceatlas_staging"
STAGING_DB_USER="postgres"

# Drop and recreate staging database
log_info "Recreating staging database..."
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -c "
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
    WHERE datname = '$STAGING_DB_NAME' AND pid <> pg_backend_pid();
" 2>/dev/null || true

docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -c "
    DROP DATABASE IF EXISTS $STAGING_DB_NAME;
" 2>/dev/null || true

docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -c "
    CREATE DATABASE $STAGING_DB_NAME;
" 2>/dev/null

# Enable PostGIS extensions
log_info "Enabling PostGIS extensions..."
docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -c "
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
    CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
    CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
" 2>/dev/null

# Restore production data to staging database
log_info "Restoring production data to staging database..."
cat "$DUMP_FILE" | docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" 2>"$DUMP_DIR/restore.log" || {
    log_warning "Some errors occurred during restore (this may be normal for extension-related errors)"
    # Show only critical errors, not extension-related warnings
    grep -i "error" "$DUMP_DIR/restore.log" | grep -v "already exists" | grep -v "extension" | head -20 || true
}

# Verify the restore
log_info "Verifying staging database..."
TABLE_COUNT=$(docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -t -c "
    SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';
")

log_success "Staging database now contains approximately $TABLE_COUNT tables"

# Anonymize sensitive data (optional - only if ANONYMIZE_STAGING_DATA is set)
if [ "$ANONYMIZE_STAGING_DATA" = "true" ]; then
    log_info "Anonymizing sensitive data in staging database..."
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" exec -T database psql -U "$STAGING_DB_USER" -d "$STAGING_DB_NAME" -c "
        -- Anonymize user emails
        UPDATE users SET email = 'user' || id || '@staging.resilienceatlas.org'
        WHERE email NOT LIKE '%@staging.resilienceatlas.org';
        
        -- Reset passwords to a known value (optional)
        -- UPDATE users SET encrypted_password = '...';
    " 2>/dev/null || log_warning "User anonymization skipped (table may not exist)"
fi

# Clean up
log_info "Cleaning up temporary files..."
rm -rf "$DUMP_DIR"

# ============================================================================
# Sync ActiveStorage Files from Production
# ============================================================================
# ActiveStorage stores files in the backend container's storage directory.
# We need to sync these files from production to staging for images to work.
# ============================================================================

# Check if production backend is accessible for file sync
PRODUCTION_BACKEND_HOST="${PRODUCTION_BACKEND_HOST:-}"
PRODUCTION_STORAGE_PATH="${PRODUCTION_STORAGE_PATH:-/opt/resilienceatlas-production}"

if [ -n "$PRODUCTION_BACKEND_HOST" ] && [ "$SYNC_STORAGE_FILES" = "true" ]; then
    log_info "Syncing ActiveStorage files from production..."
    
    # Get the staging backend container
    STAGING_BACKEND=$(docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps -q backend 2>/dev/null | head -1)
    
    if [ -n "$STAGING_BACKEND" ]; then
        # Get the staging storage volume path
        STAGING_STORAGE_VOLUME="resilienceatlas-staging_staging_backend_storage"
        STAGING_PUBLIC_STORAGE_VOLUME="resilienceatlas-staging_staging_backend_public_storage"
        
        # Use rsync to sync storage files if ssh access is available
        if command -v rsync &> /dev/null; then
            log_info "Using rsync to sync storage files..."
            
            # Sync private storage
            rsync -avz --delete \
                "${PRODUCTION_BACKEND_HOST}:${PRODUCTION_STORAGE_PATH}/storage/" \
                "/var/lib/docker/volumes/${STAGING_STORAGE_VOLUME}/_data/" 2>/dev/null || {
                log_warning "Could not sync private storage files (rsync may not have access)"
            }
            
            # Sync public storage
            rsync -avz --delete \
                "${PRODUCTION_BACKEND_HOST}:${PRODUCTION_STORAGE_PATH}/public/storage/" \
                "/var/lib/docker/volumes/${STAGING_PUBLIC_STORAGE_VOLUME}/_data/" 2>/dev/null || {
                log_warning "Could not sync public storage files (rsync may not have access)"
            }
            
            log_success "Storage files synced from production"
        else
            log_warning "rsync not available, storage files not synced"
            log_info "Install rsync and set PRODUCTION_BACKEND_HOST to enable storage sync"
        fi
    else
        log_warning "Staging backend container not found, skipping storage file sync"
    fi
elif [ -z "$PRODUCTION_BACKEND_HOST" ]; then
    log_info "PRODUCTION_BACKEND_HOST not set, skipping storage file sync"
    log_info "Set PRODUCTION_BACKEND_HOST and SYNC_STORAGE_FILES=true to sync images"
else
    log_info "Storage file sync disabled (SYNC_STORAGE_FILES != true)"
fi

log_success "Database sync completed successfully!"
log_success "Staging database has been refreshed with production data"

exit 0
