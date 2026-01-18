#!/bin/bash
#
# CartoDB Table Export Script
#
# Extracts all non-spatial tables (tables without geometry/raster columns)
# from an old CartoDB PostgreSQL database and uploads them to S3 as gzipped CSV.
# Designed for Ubuntu 12.04 with standard PostgreSQL tools.
#
# This script exports tables that are NOT captured by the raster or vector
# export scripts - i.e., regular data tables without spatial columns.
#
# Requirements:
#   - PostgreSQL client (psql)
#   - gzip
#   - AWS CLI (aws)
#
# Usage:
#   ./export_tables_bash.sh list      # List all non-spatial tables to CSV
#   ./export_tables_bash.sh export    # Export and upload to S3
#   ./export_tables_bash.sh status    # Show export status
#   ./export_tables_bash.sh single <schema.table>  # Export single table
#

set -uo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Database connection
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-cartodb}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"

# S3 configuration
S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-cartodb-tables/}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Cleanup settings - delete local files after successful S3 upload
CLEANUP_LOCAL="${CLEANUP_LOCAL:-true}"

# Skip S3 existence check (faster, trust local status file)
SKIP_S3_CHECK="${SKIP_S3_CHECK:-false}"

# Chunking for large tables (rows)
CHUNK_SIZE="${CHUNK_SIZE:-100000}"

# Output directories
OUTPUT_DIR="${OUTPUT_DIR:-./table_exports}"
CSV_FILE="${OUTPUT_DIR}/tables.csv"
STATUS_FILE="${OUTPUT_DIR}/exported_tables.txt"
FAILED_FILE="${OUTPUT_DIR}/failed_tables.txt"
LOG_FILE="${OUTPUT_DIR}/export.log"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Touch status files
touch "${STATUS_FILE}" "${FAILED_FILE}"

# =============================================================================
# Logging Functions
# =============================================================================

log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }

# =============================================================================
# Database Functions
# =============================================================================

# Database connection string for psql
export PGPASSWORD="${DB_PASSWORD}"
PSQL_CMD="psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -t -A"

# Check prerequisites
check_prereqs() {
    local missing=()
    
    command -v psql >/dev/null 2>&1 || missing+=("psql")
    command -v gzip >/dev/null 2>&1 || missing+=("gzip")
    
    # Check for aws cli
    if [[ -n "${S3_BUCKET}" ]]; then
        if ! command -v aws >/dev/null 2>&1; then
            missing+=("aws")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
    
    # Show psql version
    local psql_version
    psql_version=$(psql --version 2>&1 | head -1)
    info "Using ${psql_version}"
    
    # Test database connection
    if ! ${PSQL_CMD} -c "SELECT 1" >/dev/null 2>&1; then
        error "Cannot connect to database ${DB_NAME} at ${DB_HOST}:${DB_PORT}"
        exit 1
    fi
    
    info "Prerequisites check passed"
}

# =============================================================================
# Table Discovery
# =============================================================================

# List all non-spatial tables in the database
# Excludes tables that have geometry columns, geography columns, or raster columns
list_tables() {
    info "Discovering non-spatial tables in database..."
    
    # Query to find all user tables that:
    # - Are not in system schemas
    # - Do not have geometry columns
    # - Do not have geography columns  
    # - Do not have raster columns
    local query="
    WITH 
    -- Tables with geometry columns
    geom_tables AS (
        SELECT DISTINCT f_table_schema AS schema, f_table_name AS tbl
        FROM geometry_columns
        WHERE f_table_schema NOT IN ('pg_catalog', 'information_schema', 'topology')
    ),
    -- Tables with geography columns
    geog_tables AS (
        SELECT DISTINCT f_table_schema AS schema, f_table_name AS tbl
        FROM geography_columns
        WHERE f_table_schema NOT IN ('pg_catalog', 'information_schema', 'topology')
    ),
    -- Tables with raster columns
    raster_tables AS (
        SELECT DISTINCT r_table_schema AS schema, r_table_name AS tbl
        FROM raster_columns
        WHERE r_table_schema NOT IN ('pg_catalog', 'information_schema', 'topology')
    ),
    -- All excluded spatial tables
    spatial_tables AS (
        SELECT schema, tbl FROM geom_tables
        UNION
        SELECT schema, tbl FROM geog_tables
        UNION
        SELECT schema, tbl FROM raster_tables
    ),
    -- All user tables
    all_tables AS (
        SELECT 
            schemaname AS schema,
            relname AS tbl,
            n_live_tup AS row_count
        FROM pg_stat_user_tables
        WHERE schemaname NOT IN ('pg_catalog', 'information_schema', 'topology', 'pg_toast')
    )
    SELECT 
        t.schema,
        t.tbl,
        t.row_count,
        COALESCE(pg_total_relation_size('\"' || t.schema || '\".\"' || t.tbl || '\"'), 0) AS size_bytes,
        (SELECT COUNT(*) FROM information_schema.columns c 
         WHERE c.table_schema = t.schema AND c.table_name = t.tbl) AS column_count
    FROM all_tables t
    LEFT JOIN spatial_tables s ON t.schema = s.schema AND t.tbl = s.tbl
    WHERE s.schema IS NULL
    ORDER BY t.schema, t.tbl;
    "
    
    # Write header
    echo "schema,table,row_count,size_bytes,column_count" > "${CSV_FILE}"
    
    # Get all data in one query
    ${PSQL_CMD} -F'|' -c "${query}" | while IFS='|' read -r schema table row_count size_bytes column_count; do
        # Skip empty lines
        [[ -z "${schema}" ]] && continue
        echo "${schema},${table},${row_count},${size_bytes},${column_count}" >> "${CSV_FILE}"
    done
    
    local count
    count=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    info "Found ${count} non-spatial tables, list written to ${CSV_FILE}"
}

# Get column names for a table (for CSV header)
get_table_columns() {
    local schema="$1"
    local table="$2"
    
    ${PSQL_CMD} -c "
        SELECT string_agg(column_name, ',' ORDER BY ordinal_position)
        FROM information_schema.columns
        WHERE table_schema = '${schema}' AND table_name = '${table}'
    " | tr -d ' '
}

# =============================================================================
# Export Functions
# =============================================================================

# Check if table already exported (in status file or S3)
is_exported() {
    local table_id="$1"
    local s3_key="$2"
    
    # Check local status file first (fast)
    if grep -qF "${table_id}" "${STATUS_FILE}" 2>/dev/null; then
        return 0
    fi
    
    # Only check S3 if bucket configured AND SKIP_S3_CHECK is not set
    if [[ -n "${S3_BUCKET}" && "${SKIP_S3_CHECK}" != "true" ]]; then
        if aws s3 ls "s3://${S3_BUCKET}/${s3_key}" >/dev/null 2>&1; then
            echo "${table_id}" >> "${STATUS_FILE}"
            return 0
        fi
    fi
    
    return 1
}

# Export a single table to gzipped CSV
export_table_csv() {
    local schema="$1"
    local table="$2"
    local output_file="$3"
    local row_count="${4:-0}"
    
    info "Exporting ${schema}.${table} to CSV (${row_count} rows)..."
    
    # Remove .gz extension if present for temp file
    local csv_file="${output_file%.gz}"
    
    # Use COPY command for efficient export
    # This outputs proper CSV with headers
    local copy_cmd="\\COPY (SELECT * FROM \"${schema}\".\"${table}\") TO STDOUT WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
    
    # Export and compress
    ${PSQL_CMD} -c "${copy_cmd}" 2>>"${LOG_FILE}" | gzip -c > "${output_file}"
    
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 && -f "${output_file}" && -s "${output_file}" ]]; then
        local file_size
        file_size=$(stat -c%s "${output_file}" 2>/dev/null || stat -f%z "${output_file}" 2>/dev/null || echo "unknown")
        info "Exported ${schema}.${table}: ${file_size} bytes (gzipped)"
        return 0
    else
        error "Failed to export ${schema}.${table}"
        rm -f "${output_file}"
        return 1
    fi
}

# Export a large table in chunks
export_table_chunked() {
    local schema="$1"
    local table="$2"
    local output_dir="$3"
    local row_count="$4"
    
    local chunks_dir="${output_dir}/${schema}_${table}_chunks"
    mkdir -p "${chunks_dir}"
    
    info "Exporting ${schema}.${table} in chunks (${row_count} rows)..."
    
    # First, get the column names for header
    local columns
    columns=$(get_table_columns "${schema}" "${table}")
    
    local offset=0
    local chunk_num=0
    local chunk_files=()
    
    while [[ ${offset} -lt ${row_count} ]]; do
        chunk_num=$((chunk_num + 1))
        local chunk_file="${chunks_dir}/chunk_$(printf '%04d' ${chunk_num}).csv.gz"
        
        info "Exporting chunk ${chunk_num} (offset ${offset})..."
        
        # For first chunk, include header
        if [[ ${offset} -eq 0 ]]; then
            local copy_cmd="\\COPY (SELECT * FROM \"${schema}\".\"${table}\" ORDER BY ctid LIMIT ${CHUNK_SIZE} OFFSET ${offset}) TO STDOUT WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')"
        else
            local copy_cmd="\\COPY (SELECT * FROM \"${schema}\".\"${table}\" ORDER BY ctid LIMIT ${CHUNK_SIZE} OFFSET ${offset}) TO STDOUT WITH (FORMAT csv, HEADER false, ENCODING 'UTF8')"
        fi
        
        ${PSQL_CMD} -c "${copy_cmd}" 2>>"${LOG_FILE}" | gzip -c > "${chunk_file}"
        
        if [[ $? -eq 0 && -f "${chunk_file}" && -s "${chunk_file}" ]]; then
            chunk_files+=("${chunk_file}")
        else
            warn "Chunk ${chunk_num} may have failed"
        fi
        
        offset=$((offset + CHUNK_SIZE))
    done
    
    info "Exported ${#chunk_files[@]} chunks for ${schema}.${table}"
    
    # Merge chunks into single file
    if [[ ${#chunk_files[@]} -gt 1 ]]; then
        merge_chunks "${chunks_dir}" "${output_dir}/${schema}_${table}.csv.gz"
        return $?
    elif [[ ${#chunk_files[@]} -eq 1 ]]; then
        mv "${chunk_files[0]}" "${output_dir}/${schema}_${table}.csv.gz"
        rmdir "${chunks_dir}" 2>/dev/null || true
        return 0
    else
        error "No chunks created for ${schema}.${table}"
        return 1
    fi
}

# Merge chunked CSV files into a single gzipped file
merge_chunks() {
    local chunks_dir="$1"
    local output_file="$2"
    
    info "Merging chunks from ${chunks_dir}..."
    
    # Concatenate gzipped chunks
    # First chunk has header, rest don't
    local first=1
    for chunk in $(ls -1 "${chunks_dir}"/chunk_*.csv.gz 2>/dev/null | sort); do
        if [[ ${first} -eq 1 ]]; then
            # First chunk: use as-is
            zcat "${chunk}"
            first=0
        else
            # Subsequent chunks: already have no header
            zcat "${chunk}"
        fi
    done | gzip -c > "${output_file}"
    
    if [[ -f "${output_file}" && -s "${output_file}" ]]; then
        local file_size
        file_size=$(stat -c%s "${output_file}" 2>/dev/null || stat -f%z "${output_file}" 2>/dev/null || echo "unknown")
        info "Merged into ${output_file} (${file_size} bytes)"
        
        # Cleanup chunks
        rm -rf "${chunks_dir}"
        return 0
    else
        error "Failed to merge chunks"
        return 1
    fi
}

# =============================================================================
# S3 Upload Functions
# =============================================================================

# Upload file to S3
upload_to_s3() {
    local local_file="$1"
    local s3_key="$2"
    
    if [[ -z "${S3_BUCKET}" ]]; then
        warn "S3_BUCKET not set, skipping upload"
        return 0
    fi
    
    local file_size
    file_size=$(stat -c%s "${local_file}" 2>/dev/null || stat -f%z "${local_file}" 2>/dev/null || echo "unknown")
    
    # Determine content type and encoding
    local content_type="text/csv"
    local content_encoding=""
    if [[ "${local_file}" == *.gz ]]; then
        content_encoding="--content-encoding gzip"
    fi
    
    info "Uploading $(basename ${local_file}) (${file_size} bytes) to s3://${S3_BUCKET}/${s3_key}"
    
    aws s3 cp "${local_file}" "s3://${S3_BUCKET}/${s3_key}" \
        --region "${AWS_REGION}" \
        --content-type "${content_type}" \
        ${content_encoding} \
        2>&1 | tee -a "${LOG_FILE}" || return 1
    
    return 0
}

# Cleanup local files after successful upload
cleanup_local_file() {
    local file_or_dir="$1"
    
    if [[ "${CLEANUP_LOCAL}" != "true" ]]; then
        return 0
    fi
    
    if [[ -f "${file_or_dir}" ]]; then
        info "Cleaning up local file: ${file_or_dir}"
        rm -f "${file_or_dir}"
    elif [[ -d "${file_or_dir}" ]]; then
        info "Cleaning up local directory: ${file_or_dir}"
        rm -rf "${file_or_dir}"
    fi
}

# =============================================================================
# Main Export Function
# =============================================================================

# Export all tables
export_tables() {
    if [[ ! -f "${CSV_FILE}" ]]; then
        warn "Table list not found, running discovery first..."
        list_tables
    fi
    
    info "Starting table export..."
    
    local total=0
    local exported=0
    local skipped=0
    local failed=0
    
    # Count total
    local total_count
    total_count=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    
    # Process each table
    tail -n +2 "${CSV_FILE}" | while IFS=',' read -r schema table row_count size_bytes column_count; do
        [[ -z "${schema}" ]] && continue
        
        total=$((total + 1))
        local table_id="${schema}.${table}"
        local filename="${schema}_${table}.csv.gz"
        local output_file="${OUTPUT_DIR}/${filename}"
        local s3_key="${S3_PREFIX}${filename}"
        
        info "[${total}/${total_count}] Processing ${table_id}..."
        
        # Skip if already exported
        if is_exported "${table_id}" "${s3_key}"; then
            info "Already exported: ${table_id}, skipping"
            skipped=$((skipped + 1))
            continue
        fi
        
        # Skip empty tables
        if [[ "${row_count}" == "0" ]]; then
            info "Empty table: ${table_id}, skipping"
            echo "${table_id}|empty" >> "${FAILED_FILE}"
            continue
        fi
        
        local export_success="false"
        
        # Choose export method based on row count
        if [[ ${row_count} -gt ${CHUNK_SIZE} ]]; then
            # Large table - use chunked export
            if export_table_chunked "${schema}" "${table}" "${OUTPUT_DIR}" "${row_count}"; then
                export_success="true"
            fi
        else
            # Normal table - direct export
            if export_table_csv "${schema}" "${table}" "${output_file}" "${row_count}"; then
                export_success="true"
            fi
        fi
        
        if [[ "${export_success}" == "true" ]]; then
            # Upload to S3
            if upload_to_s3 "${output_file}" "${s3_key}"; then
                echo "${table_id}" >> "${STATUS_FILE}"
                exported=$((exported + 1))
                info "Successfully exported and uploaded ${table_id}"
                # Cleanup local file
                cleanup_local_file "${output_file}"
            else
                error "S3 upload failed for ${table_id}"
                echo "${table_id}|upload_failed" >> "${FAILED_FILE}"
                failed=$((failed + 1))
            fi
        else
            error "Export failed for ${table_id}"
            echo "${table_id}|export_failed" >> "${FAILED_FILE}"
            failed=$((failed + 1))
        fi
    done
    
    info "Export complete: ${exported} exported, ${skipped} skipped, ${failed} failed"
}

# Export a single table
export_single() {
    local full_table="$1"
    
    # Parse schema.table
    local schema="${full_table%%.*}"
    local table="${full_table#*.}"
    
    if [[ -z "${schema}" || -z "${table}" || "${schema}" == "${table}" ]]; then
        error "Invalid table name. Use format: schema.table"
        exit 1
    fi
    
    info "Exporting single table: ${schema}.${table}"
    
    # Get row count
    local row_count
    row_count=$(${PSQL_CMD} -c "SELECT COUNT(*) FROM \"${schema}\".\"${table}\"" 2>/dev/null | tr -d ' ')
    
    if [[ -z "${row_count}" || "${row_count}" == "0" ]]; then
        warn "Table ${schema}.${table} is empty or doesn't exist"
        return 1
    fi
    
    local output_file="${OUTPUT_DIR}/${schema}_${table}.csv.gz"
    local s3_key="${S3_PREFIX}${schema}_${table}.csv.gz"
    
    # Export
    if [[ ${row_count} -gt ${CHUNK_SIZE} ]]; then
        export_table_chunked "${schema}" "${table}" "${OUTPUT_DIR}" "${row_count}"
    else
        export_table_csv "${schema}" "${table}" "${output_file}" "${row_count}"
    fi
    
    if [[ $? -eq 0 ]]; then
        upload_to_s3 "${output_file}" "${s3_key}"
        cleanup_local_file "${output_file}"
    fi
}

# =============================================================================
# Status Functions
# =============================================================================

# Show export status
show_status() {
    if [[ ! -f "${CSV_FILE}" ]]; then
        warn "Table list not found, run 'list' first"
        return 1
    fi
    
    local total
    total=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    
    local exported=0
    local failed=0
    
    [[ -f "${STATUS_FILE}" ]] && exported=$(wc -l < "${STATUS_FILE}" | tr -d ' ')
    [[ -f "${FAILED_FILE}" ]] && failed=$(wc -l < "${FAILED_FILE}" | tr -d ' ')
    
    local remaining=$((total - exported))
    
    echo ""
    echo "=========================================="
    echo "  Table Export Status"
    echo "=========================================="
    echo "  Total tables:     ${total}"
    echo "  Exported:         ${exported}"
    echo "  Failed:           ${failed}"
    echo "  Remaining:        ${remaining}"
    echo "=========================================="
    echo ""
    
    if [[ ${failed} -gt 0 ]]; then
        echo "Failed tables:"
        head -10 "${FAILED_FILE}"
        [[ $(wc -l < "${FAILED_FILE}") -gt 10 ]] && echo "... and more"
        echo ""
    fi
}

# Retry failed exports
retry_failed() {
    if [[ ! -f "${FAILED_FILE}" || ! -s "${FAILED_FILE}" ]]; then
        info "No failed exports to retry"
        return 0
    fi
    
    info "Retrying failed exports..."
    
    # Backup failed file
    cp "${FAILED_FILE}" "${FAILED_FILE}.bak"
    > "${FAILED_FILE}"
    
    while IFS='|' read -r table_id reason; do
        [[ -z "${table_id}" ]] && continue
        
        info "Retrying: ${table_id}"
        export_single "${table_id}"
    done < "${FAILED_FILE}.bak"
    
    rm -f "${FAILED_FILE}.bak"
}

# =============================================================================
# Help
# =============================================================================

show_help() {
    cat <<EOF
CartoDB Table Export Script

Exports non-spatial tables (without geometry/raster columns) to gzipped CSV
and uploads to S3. Designed for Ubuntu 12.04 with PostgreSQL 9.6.

Usage: $0 <command> [options]

Commands:
    list     Discover all non-spatial tables and write to CSV
    export   Export tables and upload to S3
    status   Show export status
    retry    Retry failed exports
    single   Export a single table: $0 single schema.table

Environment Variables:
    DB_HOST       Database host (default: localhost)
    DB_PORT       Database port (default: 5432)
    DB_NAME       Database name (default: cartodb)
    DB_USER       Database user (default: postgres)
    DB_PASSWORD   Database password

    S3_BUCKET     S3 bucket name (required for upload)
    S3_PREFIX     S3 key prefix (default: cartodb-tables/)
    AWS_DEFAULT_REGION  AWS region (default: us-east-1)

    OUTPUT_DIR    Local output directory (default: ./table_exports)
    CLEANUP_LOCAL Delete local files after S3 upload (default: true)
    SKIP_S3_CHECK Skip checking S3 for existing files (default: false)
    CHUNK_SIZE    Rows per chunk for large tables (default: 100000)

Examples:
    # Set up environment
    export DB_HOST=localhost DB_NAME=cartodb_user_db
    export DB_USER=postgres DB_PASSWORD=secret
    export S3_BUCKET=my-bucket S3_PREFIX=tables/

    # List all non-spatial tables
    $0 list

    # Export all tables
    $0 export

    # Export a single table
    $0 single public.my_table

    # Check progress
    $0 status

    # Retry any failed exports
    $0 retry

Notes:
    - Only exports tables WITHOUT geometry, geography, or raster columns
    - Tables exported by vector/raster scripts are automatically excluded
    - Output is gzipped CSV with UTF-8 encoding
    - Large tables (>${CHUNK_SIZE} rows) are exported in chunks then merged
    - Export progress is saved, so you can stop and resume
    - Tables already in S3 are skipped (unless removed from status file)
EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    local command="${1:-help}"
    shift || true
    
    case "${command}" in
        list)
            check_prereqs
            list_tables
            ;;
        export)
            check_prereqs
            export_tables
            ;;
        status)
            show_status
            ;;
        retry)
            check_prereqs
            retry_failed
            ;;
        single)
            check_prereqs
            export_single "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
