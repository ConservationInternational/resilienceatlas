#!/bin/bash
#
# CartoDB Raster Export Script
#
# Extracts all rasters from an old CartoDB PostgreSQL/PostGIS database
# and uploads them to S3. Designed for Ubuntu 12.04 with GDAL 1.11.
#
# Requirements:
#   - PostgreSQL client (psql)
#   - GDAL 1.11+ (gdal_translate, gdalinfo)
#   - AWS CLI (aws)
#
# Usage:
#   ./export_rasters_bash.sh list      # List all rasters to CSV
#   ./export_rasters_bash.sh export    # Export and upload to S3
#   ./export_rasters_bash.sh status    # Show export status
#

set -uo pipefail

# Configuration - set these via environment variables or edit here
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-cartodb}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"

S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-cartodb-rasters/}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Cleanup settings - delete local files after successful S3 upload to save disk space
CLEANUP_LOCAL="${CLEANUP_LOCAL:-true}"

# Output directories
OUTPUT_DIR="${OUTPUT_DIR:-./raster_exports}"
CSV_FILE="${OUTPUT_DIR}/rasters.csv"
STATUS_FILE="${OUTPUT_DIR}/exported_rasters.txt"
FAILED_FILE="${OUTPUT_DIR}/failed_rasters.txt"
LOG_FILE="${OUTPUT_DIR}/export.log"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Touch status files
touch "${STATUS_FILE}" "${FAILED_FILE}"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }

# Database connection string for psql
export PGPASSWORD="${DB_PASSWORD}"
PSQL_CMD="psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -t -A"

# Check prerequisites
check_prereqs() {
    local missing=()
    
    command -v psql >/dev/null 2>&1 || missing+=("psql")
    command -v gdal_translate >/dev/null 2>&1 || missing+=("gdal_translate")
    
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
    
    # Show GDAL version
    local gdal_version
    gdal_version=$(gdal_translate --version 2>&1 | head -1)
    info "Using ${gdal_version}"
    
    # Test database connection
    if ! ${PSQL_CMD} -c "SELECT 1" >/dev/null 2>&1; then
        error "Cannot connect to database ${DB_NAME} at ${DB_HOST}:${DB_PORT}"
        exit 1
    fi
    
    info "Prerequisites check passed"
}

# List all rasters in the database
list_rasters() {
    info "Discovering rasters in database..."
    
    # Query raster_columns view with tile counts in a single efficient query
    local query="
    WITH raster_info AS (
        SELECT 
            r_table_schema,
            r_table_name,
            r_raster_column,
            srid,
            num_bands,
            scale_x,
            scale_y,
            blocksize_x,
            blocksize_y
        FROM raster_columns
    ),
    table_counts AS (
        SELECT 
            schemaname as schema,
            relname as tbl,
            n_live_tup as row_count
        FROM pg_stat_user_tables
    )
    SELECT 
        r.r_table_schema,
        r.r_table_name,
        r.r_raster_column,
        r.srid,
        r.num_bands,
        r.scale_x,
        r.scale_y,
        r.blocksize_x,
        r.blocksize_y,
        COALESCE(c.row_count, 0) as num_tiles
    FROM raster_info r
    LEFT JOIN table_counts c ON r.r_table_schema = c.schema AND r.r_table_name = c.tbl
    ORDER BY r.r_table_schema, r.r_table_name;
    "
    
    # Write header
    echo "schema,table,column,srid,num_bands,scale_x,scale_y,blocksize_x,blocksize_y,num_tiles" > "${CSV_FILE}"
    
    # Get all data in one query
    ${PSQL_CMD} -F'|' -c "${query}" | while IFS='|' read -r schema table column srid bands scale_x scale_y block_x block_y num_tiles; do
        # Skip empty lines
        [[ -z "${schema}" ]] && continue
        echo "${schema},${table},${column},${srid},${bands},${scale_x},${scale_y},${block_x},${block_y},${num_tiles}" >> "${CSV_FILE}"
    done
    
    local count
    count=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    info "Found ${count} rasters, list written to ${CSV_FILE}"
}

# Check if raster already exported (in status file or S3)
# Optimized: only check S3 if not in local status file
is_exported() {
    local raster_id="$1"
    local s3_key="$2"
    
    # Check local status file first (fast)
    if grep -qF "${raster_id}" "${STATUS_FILE}" 2>/dev/null; then
        return 0
    fi
    
    # Only check S3 if bucket configured AND SKIP_S3_CHECK is not set
    # Set SKIP_S3_CHECK=true for faster runs when you trust the status file
    if [[ -n "${S3_BUCKET}" && "${SKIP_S3_CHECK:-false}" != "true" ]]; then
        if aws s3 ls "s3://${S3_BUCKET}/${s3_key}" >/dev/null 2>&1; then
            echo "${raster_id}" >> "${STATUS_FILE}"
            return 0
        fi
    fi
    
    return 1
}

# Export a single raster using GDAL
# GDAL 1.11 compatible connection string format
export_raster_gdal() {
    local schema="$1"
    local table="$2"
    local column="$3"
    local output_file="$4"
    local srid="${5:-0}"
    
    # GDAL 1.11 PostGIS Raster connection string
    # Must be quoted, spaces between parameters
    # mode=2 merges tiles into single raster
    local gdal_conn="PG:host=${DB_HOST} port=${DB_PORT} dbname='${DB_NAME}' user='${DB_USER}' password='${DB_PASSWORD}' schema='${schema}' table='${table}' column='${column}' mode=2"
    
    info "Trying GDAL export for ${schema}.${table}.${column}..."
    
    # Build gdal_translate command with GDAL 1.11 compatible options
    # - COMPRESS=LZW is safe and widely supported
    # - TILED=YES creates tiled GeoTIFF
    # - BIGTIFF=IF_SAFER handles large files automatically
    # - a_srs sets the spatial reference if SRID is known
    local gdal_opts=()
    gdal_opts+=("-of" "GTiff")
    gdal_opts+=("-co" "COMPRESS=LZW")
    gdal_opts+=("-co" "TILED=YES")
    gdal_opts+=("-co" "BIGTIFF=IF_SAFER")
    
    # Set spatial reference if SRID is valid (> 0)
    if [[ "${srid}" =~ ^[0-9]+$ && "${srid}" -gt 0 ]]; then
        gdal_opts+=("-a_srs" "EPSG:${srid}")
        info "Setting spatial reference to EPSG:${srid}"
    fi
    
    if gdal_translate \
        "${gdal_opts[@]}" \
        "${gdal_conn}" \
        "${output_file}" 2>&1 | tee -a "${LOG_FILE}"; then
        
        # Check output file exists and has size > 0
        if [[ -f "${output_file}" && -s "${output_file}" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Alternative: Export using SQL ST_AsTIFF (fallback if GDAL fails)
export_raster_sql() {
    local schema="$1"
    local table="$2"
    local column="$3"
    local output_file="$4"
    local srid="${5:-0}"
    
    info "Trying SQL export for ${schema}.${table}.${column}..."
    
    # For single-tile rasters, export directly
    # For tiled rasters, union first then export
    # Use ST_SetSRID to ensure SRID is embedded in the output
    local query
    if [[ "${srid}" =~ ^[0-9]+$ && "${srid}" -gt 0 ]]; then
        query="
        COPY (
            SELECT encode(
                ST_AsTIFF(
                    ST_SetSRID(ST_Union(\"${column}\"), ${srid}),
                    'LZW'
                ),
                'hex'
            )
            FROM \"${schema}\".\"${table}\"
        ) TO STDOUT;
        "
    else
        query="
        COPY (
            SELECT encode(
                ST_AsTIFF(
                    ST_Union(\"${column}\"),
                    'LZW'
                ),
                'hex'
            )
            FROM \"${schema}\".\"${table}\"
        ) TO STDOUT;
        "
    fi
    
    # Export hex-encoded TIFF, then decode
    local hex_output
    hex_output=$(${PSQL_CMD} -c "${query}" 2>/dev/null)
    
    if [[ -n "${hex_output}" ]]; then
        # Decode hex to binary
        # Use xxd if available, otherwise use printf
        if command -v xxd >/dev/null 2>&1; then
            echo "${hex_output}" | xxd -r -p > "${output_file}"
        else
            # Fallback: use printf (slower but more portable)
            local i=0
            local len=${#hex_output}
            > "${output_file}"  # Truncate file
            while [[ $i -lt $len ]]; do
                printf "\\x${hex_output:$i:2}" >> "${output_file}"
                i=$((i + 2))
            done
        fi
        
        # Assign SRS using gdal_edit or gdal_translate if SRID known and gdal available
        if [[ -f "${output_file}" && -s "${output_file}" ]]; then
            if [[ "${srid}" =~ ^[0-9]+$ && "${srid}" -gt 0 ]]; then
                # Try gdal_edit.py first (in-place), fall back to gdal_translate
                if command -v gdal_edit.py >/dev/null 2>&1; then
                    gdal_edit.py -a_srs "EPSG:${srid}" "${output_file}" 2>/dev/null || true
                elif command -v gdal_translate >/dev/null 2>&1; then
                    local temp_file="${output_file}.tmp"
                    if gdal_translate -a_srs "EPSG:${srid}" "${output_file}" "${temp_file}" 2>/dev/null; then
                        mv "${temp_file}" "${output_file}"
                    else
                        rm -f "${temp_file}"
                    fi
                fi
            fi
            return 0
        fi
    fi
    
    return 1
}

# Export individual tiles for very large rasters
export_raster_tiles() {
    local schema="$1"
    local table="$2"
    local column="$3"
    local output_dir="$4"
    local srid="${5:-0}"
    
    info "Exporting ${schema}.${table}.${column} as individual tiles..."
    
    local tiles_dir="${output_dir}/${schema}_${table}_tiles"
    mkdir -p "${tiles_dir}"
    
    # Get all tile IDs
    local query="SELECT COALESCE(rid, row_number() OVER ()) as tile_id FROM \"${schema}\".\"${table}\" ORDER BY 1"
    
    ${PSQL_CMD} -c "${query}" | while read -r tile_id; do
        [[ -z "${tile_id}" ]] && continue
        tile_id=$(echo "${tile_id}" | tr -d ' ')
        
        local tile_file="${tiles_dir}/tile_$(printf '%06d' ${tile_id}).tif"
        
        # Skip if already exported
        [[ -f "${tile_file}" ]] && continue
        
        # Export single tile with SRID if available
        local tile_query
        if [[ "${srid}" =~ ^[0-9]+$ && "${srid}" -gt 0 ]]; then
            tile_query="
            COPY (
                SELECT encode(ST_AsTIFF(ST_SetSRID(\"${column}\", ${srid}), 'LZW'), 'hex')
                FROM \"${schema}\".\"${table}\"
                WHERE COALESCE(rid, ctid::text::bigint) = ${tile_id}
                LIMIT 1
            ) TO STDOUT;
            "
        else
            tile_query="
            COPY (
                SELECT encode(ST_AsTIFF(\"${column}\", 'LZW'), 'hex')
                FROM \"${schema}\".\"${table}\"
                WHERE COALESCE(rid, ctid::text::bigint) = ${tile_id}
                LIMIT 1
            ) TO STDOUT;
            "
        fi
        
        local hex_output
        hex_output=$(${PSQL_CMD} -c "${tile_query}" 2>/dev/null)
        
        if [[ -n "${hex_output}" ]] && command -v xxd >/dev/null 2>&1; then
            echo "${hex_output}" | xxd -r -p > "${tile_file}"
        fi
    done
    
    # Check if we got any tiles
    local tile_count
    tile_count=$(find "${tiles_dir}" -name "*.tif" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ ${tile_count} -gt 0 ]]; then
        info "Exported ${tile_count} tiles to ${tiles_dir}"
        return 0
    fi
    
    return 1
}

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
    
    info "Uploading $(basename ${local_file}) (${file_size} bytes) to s3://${S3_BUCKET}/${s3_key}"
    
    aws s3 cp "${local_file}" "s3://${S3_BUCKET}/${s3_key}" \
        --region "${AWS_REGION}" \
        --content-type "image/tiff" \
        2>&1 | tee -a "${LOG_FILE}" || return 1
    
    return 0
}

# Upload a directory of tiles to S3
upload_tiles_to_s3() {
    local tiles_dir="$1"
    local s3_prefix="$2"
    
    if [[ -z "${S3_BUCKET}" ]]; then
        warn "S3_BUCKET not set, skipping upload"
        return 0
    fi
    
    info "Uploading tiles directory to s3://${S3_BUCKET}/${s3_prefix}"
    
    aws s3 sync "${tiles_dir}" "s3://${S3_BUCKET}/${s3_prefix}" \
        --region "${AWS_REGION}" \
        --content-type "image/tiff" \
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

# Export all rasters
export_rasters() {
    if [[ ! -f "${CSV_FILE}" ]]; then
        warn "Raster list not found, running discovery first..."
        list_rasters
    fi
    
    info "Starting raster export..."
    
    local total=0
    local exported=0
    local skipped=0
    local failed=0
    
    # Count total
    local total_count
    total_count=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    
    # Process each raster
    tail -n +2 "${CSV_FILE}" | while IFS=',' read -r schema table column srid bands scale_x scale_y block_x block_y num_tiles; do
        [[ -z "${schema}" ]] && continue
        
        total=$((total + 1))
        local raster_id="${schema}.${table}"
        local filename="${schema}_${table}.tif"
        local output_file="${OUTPUT_DIR}/${filename}"
        # Use flat S3 path: prefix/schema_table.tif
        local s3_key="${S3_PREFIX}${schema}_${table}.tif"
        
        echo ""
        info "[${total}/${total_count}] Processing ${raster_id} (${num_tiles} tiles, SRID: ${srid})..."
        
        # Check if already exported
        if is_exported "${raster_id}" "${s3_key}"; then
            info "Skipping ${raster_id} - already exported"
            skipped=$((skipped + 1))
            continue
        fi
        
        local export_success=false
        
        # Try GDAL first (most efficient) - pass SRID for SRS assignment
        if export_raster_gdal "${schema}" "${table}" "${column}" "${output_file}" "${srid}"; then
            info "GDAL export successful"
            export_success=true
        else
            warn "GDAL export failed, trying SQL method..."
            
            # Try SQL export with SRID
            if export_raster_sql "${schema}" "${table}" "${column}" "${output_file}" "${srid}"; then
                info "SQL export successful"
                export_success=true
            else
                # For large rasters, try tile export
                if [[ ${num_tiles} -gt 10 ]]; then
                    warn "SQL export failed, trying tile export..."
                    if export_raster_tiles "${schema}" "${table}" "${column}" "${OUTPUT_DIR}" "${srid}"; then
                        # Upload tiles directory
                        local tiles_dir="${OUTPUT_DIR}/${schema}_${table}_tiles"
                        local tiles_s3_prefix="${S3_PREFIX}${schema}_${table}_tiles/"
                        
                        if upload_tiles_to_s3 "${tiles_dir}" "${tiles_s3_prefix}"; then
                            echo "${raster_id}" >> "${STATUS_FILE}"
                            exported=$((exported + 1))
                            # Cleanup tiles directory after successful upload
                            cleanup_local_file "${tiles_dir}"
                            continue
                        fi
                    fi
                fi
            fi
        fi
        
        if [[ "${export_success}" == "true" ]]; then
            # Upload to S3
            if upload_to_s3 "${output_file}" "${s3_key}"; then
                echo "${raster_id}" >> "${STATUS_FILE}"
                exported=$((exported + 1))
                info "Successfully exported and uploaded ${raster_id}"
                
                # Cleanup local file after successful upload
                cleanup_local_file "${output_file}"
            else
                error "S3 upload failed for ${raster_id}"
                echo "${raster_id}|upload_failed" >> "${FAILED_FILE}"
                failed=$((failed + 1))
            fi
        else
            error "All export methods failed for ${raster_id}"
            echo "${raster_id}|export_failed" >> "${FAILED_FILE}"
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    info "=========================================="
    info "Export complete!"
    info "  Total processed: ${total_count}"
    info "  Check ${STATUS_FILE} for exported rasters"
    info "  Check ${FAILED_FILE} for failures"
    info "=========================================="
}

# Show export status
show_status() {
    echo ""
    echo "=== Export Status ==="
    echo ""
    
    if [[ -f "${CSV_FILE}" ]]; then
        local total
        total=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
        echo "Total rasters discovered: ${total}"
    else
        echo "Raster list not created yet. Run: $0 list"
    fi
    
    if [[ -f "${STATUS_FILE}" ]]; then
        local exported
        exported=$(wc -l < "${STATUS_FILE}" | tr -d ' ')
        echo "Successfully exported: ${exported}"
    else
        echo "Successfully exported: 0"
    fi
    
    if [[ -f "${FAILED_FILE}" && -s "${FAILED_FILE}" ]]; then
        local failed
        failed=$(wc -l < "${FAILED_FILE}" | tr -d ' ')
        echo "Failed exports: ${failed}"
        echo ""
        echo "Failed rasters:"
        cat "${FAILED_FILE}"
    else
        echo "Failed exports: 0"
    fi
    
    echo ""
}

# Retry failed exports
retry_failed() {
    if [[ ! -f "${FAILED_FILE}" || ! -s "${FAILED_FILE}" ]]; then
        info "No failed exports to retry"
        return 0
    fi
    
    info "Retrying failed exports..."
    
    # Move failed file to temp
    local temp_failed="${FAILED_FILE}.retry"
    mv "${FAILED_FILE}" "${temp_failed}"
    touch "${FAILED_FILE}"
    
    while IFS='|' read -r raster_id reason; do
        [[ -z "${raster_id}" ]] && continue
        
        # Parse raster_id (schema.table format)
        local schema table column srid
        schema=$(echo "${raster_id}" | cut -d. -f1)
        table=$(echo "${raster_id}" | cut -d. -f2)
        
        # Get column and srid from CSV
        local csv_line
        csv_line=$(grep "^${schema},${table}," "${CSV_FILE}" | head -1)
        column=$(echo "${csv_line}" | cut -d',' -f3)
        srid=$(echo "${csv_line}" | cut -d',' -f4)
        
        if [[ -z "${column}" ]]; then
            warn "Could not find raster column for ${raster_id}, skipping"
            echo "${raster_id}|no_column" >> "${FAILED_FILE}"
            continue
        fi
        
        local filename="${schema}_${table}.tif"
        local output_file="${OUTPUT_DIR}/${filename}"
        local s3_key="${S3_PREFIX}${schema}_${table}.tif"
        
        info "Retrying ${raster_id}..."
        
        # Remove from status if present (force re-export)
        sed -i "/${raster_id}/d" "${STATUS_FILE}" 2>/dev/null || true
        
        local export_success=false
        
        if export_raster_gdal "${schema}" "${table}" "${column}" "${output_file}" "${srid}"; then
            export_success=true
        elif export_raster_sql "${schema}" "${table}" "${column}" "${output_file}" "${srid}"; then
            export_success=true
        fi
        
        if [[ "${export_success}" == "true" ]]; then
            if upload_to_s3 "${output_file}" "${s3_key}"; then
                echo "${raster_id}" >> "${STATUS_FILE}"
                info "Retry successful for ${raster_id}"
                cleanup_local_file "${output_file}"
            else
                echo "${raster_id}|upload_failed" >> "${FAILED_FILE}"
            fi
        else
            echo "${raster_id}|export_failed" >> "${FAILED_FILE}"
        fi
    done < "${temp_failed}"
    
    rm -f "${temp_failed}"
    
    show_status
}

# Test GDAL PostGIS raster driver
test_gdal() {
    info "Testing GDAL PostGIS Raster driver..."
    
    # Check if driver is available
    if ! gdalinfo --formats 2>/dev/null | grep -qi "PostGIS Raster"; then
        error "GDAL PostGIS Raster driver not found!"
        error "You may need to rebuild GDAL with PostgreSQL support"
        return 1
    fi
    
    info "PostGIS Raster driver is available"
    
    # Try to list rasters via GDAL
    local gdal_conn="PG:host=${DB_HOST} port=${DB_PORT} dbname='${DB_NAME}' user='${DB_USER}' password='${DB_PASSWORD}'"
    
    info "Testing connection to database..."
    if gdalinfo "${gdal_conn}" 2>&1 | head -20; then
        info "GDAL can connect to database"
        return 0
    else
        warn "GDAL connection test had issues, but may still work for individual tables"
        return 0
    fi
}

# Main
main() {
    local command="${1:-help}"
    
    case "${command}" in
        list)
            check_prereqs
            list_rasters
            ;;
        export)
            check_prereqs
            export_rasters
            ;;
        status)
            show_status
            ;;
        retry)
            check_prereqs
            retry_failed
            ;;
        test)
            check_prereqs
            test_gdal
            ;;
        help|--help|-h)
            cat <<EOF
CartoDB Raster Export Script

Exports PostGIS rasters to GeoTIFF and uploads to S3.
Compatible with GDAL 1.11+ on Ubuntu 12.04.

Usage: $0 <command>

Commands:
    list     Discover all rasters and write to CSV
    export   Export rasters and upload to S3
    status   Show export status
    retry    Retry failed exports
    test     Test GDAL PostGIS Raster driver

Environment variables:
    DB_HOST       Database host (default: localhost)
    DB_PORT       Database port (default: 5432)
    DB_NAME       Database name (default: cartodb)
    DB_USER       Database user (default: postgres)
    DB_PASSWORD   Database password

    S3_BUCKET     S3 bucket name (required for upload)
    S3_PREFIX     S3 key prefix (default: cartodb-rasters/)
    AWS_DEFAULT_REGION  AWS region (default: us-east-1)

    OUTPUT_DIR    Local output directory (default: ./raster_exports)
    CLEANUP_LOCAL Delete local files after S3 upload (default: true)

Examples:
    # Set up environment
    export DB_HOST=localhost DB_NAME=cartodb_user_db
    export DB_USER=postgres DB_PASSWORD=secret
    export S3_BUCKET=my-bucket S3_PREFIX=rasters/

    # Test GDAL driver
    $0 test

    # List all rasters to CSV
    $0 list

    # Export and upload to S3
    $0 export

    # Check progress
    $0 status

    # Retry any failed exports
    $0 retry

Export Methods (tried in order):
    1. GDAL gdal_translate - Most efficient, uses PostGIS Raster driver
    2. SQL ST_AsTIFF - Direct PostgreSQL export via psql
    3. Tile export - For large rasters, exports individual tiles

Notes:
    - Export progress is saved, so you can stop and resume
    - Rasters already in S3 are skipped (unless you remove from status file)
    - Large rasters (>10 tiles) will try tile export if other methods fail
EOF
            ;;
        *)
            error "Unknown command: ${command}"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
