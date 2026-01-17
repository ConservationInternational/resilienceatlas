#!/bin/bash
#
# CartoDB Vector Export Script
#
# Extracts all vector tables (with geometry columns) from an old CartoDB 
# PostgreSQL/PostGIS database and uploads them to S3.
# Designed for Ubuntu 12.04 with GDAL/OGR 1.11.
#
# Requirements:
#   - PostgreSQL client (psql)
#   - GDAL/OGR 1.11+ (ogr2ogr, ogrinfo)
#   - AWS CLI (aws) or s3cmd
#
# Usage:
#   ./export_vectors_bash.sh list      # List all vector tables to CSV
#   ./export_vectors_bash.sh export    # Export and upload to S3
#   ./export_vectors_bash.sh status    # Show export status
#

set -uo pipefail

# Configuration - set these via environment variables or edit here
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-cartodb}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-}"

S3_BUCKET="${S3_BUCKET:-}"
S3_PREFIX="${S3_PREFIX:-cartodb-vectors/}"
AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Export format: geojson, shapefile, or gpkg (GeoPackage)
# geojson is most portable and recommended for GDAL 1.11
# shapefile has 2GB/10char field name limits
# gpkg was introduced in GDAL 1.11 but may not be compiled in
EXPORT_FORMAT="${EXPORT_FORMAT:-geojson}"

# Output directories
OUTPUT_DIR="${OUTPUT_DIR:-./vector_exports}"
CSV_FILE="${OUTPUT_DIR}/vectors.csv"
STATUS_FILE="${OUTPUT_DIR}/exported_vectors.txt"
FAILED_FILE="${OUTPUT_DIR}/failed_vectors.txt"
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

# Get file extension for export format
get_extension() {
    case "${EXPORT_FORMAT}" in
        geojson) echo "geojson" ;;
        shapefile|shp) echo "shp" ;;
        gpkg|geopackage) echo "gpkg" ;;
        *) echo "geojson" ;;
    esac
}

# Get OGR driver name for export format
get_driver() {
    case "${EXPORT_FORMAT}" in
        geojson) echo "GeoJSON" ;;
        shapefile|shp) echo "ESRI Shapefile" ;;
        gpkg|geopackage) echo "GPKG" ;;
        *) echo "GeoJSON" ;;
    esac
}

# Check prerequisites
check_prereqs() {
    local missing=()
    
    command -v psql >/dev/null 2>&1 || missing+=("psql")
    command -v ogr2ogr >/dev/null 2>&1 || missing+=("ogr2ogr")
    
    # Check for aws or s3cmd
    if [[ -n "${S3_BUCKET}" ]]; then
        if ! command -v aws >/dev/null 2>&1 && ! command -v s3cmd >/dev/null 2>&1; then
            missing+=("aws or s3cmd")
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing[*]}"
        exit 1
    fi
    
    # Show OGR version
    local ogr_version
    ogr_version=$(ogr2ogr --version 2>&1 | head -1)
    info "Using ${ogr_version}"
    
    # Check if selected format driver is available
    local driver
    driver=$(get_driver)
    if ! ogrinfo --formats 2>/dev/null | grep -qi "${driver}"; then
        warn "Driver '${driver}' may not be available, will try anyway"
    fi
    
    # Test database connection
    if ! ${PSQL_CMD} -c "SELECT 1" >/dev/null 2>&1; then
        error "Cannot connect to database ${DB_NAME} at ${DB_HOST}:${DB_PORT}"
        exit 1
    fi
    
    info "Prerequisites check passed"
    info "Export format: ${EXPORT_FORMAT} (driver: ${driver})"
}

# List all vector tables in the database
list_vectors() {
    info "Discovering vector tables in database..."
    
    # Query geometry_columns view for vector metadata
    # Also check for geography columns
    local query="
    SELECT 
        f_table_schema,
        f_table_name,
        f_geometry_column,
        coord_dimension,
        srid,
        type
    FROM geometry_columns
    WHERE f_table_schema NOT IN ('pg_catalog', 'information_schema', 'topology')
    UNION ALL
    SELECT 
        f_table_schema,
        f_table_name,
        f_geography_column,
        coord_dimension,
        srid,
        type
    FROM geography_columns
    WHERE f_table_schema NOT IN ('pg_catalog', 'information_schema', 'topology')
    ORDER BY 1, 2, 3;
    "
    
    # Write header
    echo "schema,table,geometry_column,coord_dimension,srid,geometry_type,row_count,size_bytes" > "${CSV_FILE}"
    
    local count=0
    
    # Get vector list
    ${PSQL_CMD} -F'|' -c "${query}" | while IFS='|' read -r schema table geom_col coord_dim srid geom_type; do
        # Skip empty lines
        [[ -z "${schema}" ]] && continue
        
        # Get row count
        local count_query="SELECT COUNT(*) FROM \"${schema}\".\"${table}\""
        local row_count
        row_count=$(${PSQL_CMD} -c "${count_query}" 2>/dev/null | tr -d ' ' || echo "0")
        
        # Get table size
        local size_query="SELECT pg_total_relation_size('\"${schema}\".\"${table}\"')"
        local size_bytes
        size_bytes=$(${PSQL_CMD} -c "${size_query}" 2>/dev/null | tr -d ' ' || echo "0")
        
        echo "${schema},${table},${geom_col},${coord_dim},${srid},${geom_type},${row_count},${size_bytes}" >> "${CSV_FILE}"
        count=$((count + 1))
    done
    
    count=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    info "Found ${count} vector tables, list written to ${CSV_FILE}"
}

# Check if vector already exported (in status file or S3)
is_exported() {
    local vector_id="$1"
    local s3_key="$2"
    
    # Check local status file
    if grep -qF "${vector_id}" "${STATUS_FILE}" 2>/dev/null; then
        return 0
    fi
    
    # Check S3 if bucket configured
    if [[ -n "${S3_BUCKET}" ]]; then
        if command -v aws >/dev/null 2>&1; then
            if aws s3 ls "s3://${S3_BUCKET}/${s3_key}" >/dev/null 2>&1; then
                echo "${vector_id}" >> "${STATUS_FILE}"
                return 0
            fi
        elif command -v s3cmd >/dev/null 2>&1; then
            if s3cmd ls "s3://${S3_BUCKET}/${s3_key}" >/dev/null 2>&1; then
                echo "${vector_id}" >> "${STATUS_FILE}"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Export a vector table using ogr2ogr
# GDAL/OGR 1.11 compatible
export_vector_ogr() {
    local schema="$1"
    local table="$2"
    local geom_col="$3"
    local output_file="$4"
    
    local driver
    driver=$(get_driver)
    
    # OGR PostgreSQL connection string for GDAL 1.11
    # Format: PG:"host=xxx dbname=xxx user=xxx password=xxx"
    local ogr_conn="PG:host=${DB_HOST} port=${DB_PORT} dbname='${DB_NAME}' user='${DB_USER}' password='${DB_PASSWORD}'"
    
    # SQL to select from the table with proper schema
    local sql="SELECT * FROM \"${schema}\".\"${table}\""
    
    info "Trying OGR export for ${schema}.${table}..."
    
    # Remove existing output file/directory
    rm -rf "${output_file}" "${output_file%.shp}.dbf" "${output_file%.shp}.shx" "${output_file%.shp}.prj" 2>/dev/null
    
    # ogr2ogr options for GDAL 1.11:
    # -f: output format
    # -sql: SQL query to execute
    # -lco: layer creation options
    # -overwrite: overwrite existing
    local ogr_opts=()
    ogr_opts+=("-f" "${driver}")
    
    # Format-specific options
    case "${EXPORT_FORMAT}" in
        geojson)
            # GeoJSON options - write coordinates with precision
            ogr_opts+=("-lco" "COORDINATE_PRECISION=6")
            ;;
        shapefile|shp)
            # Shapefile options - encoding
            ogr_opts+=("-lco" "ENCODING=UTF-8")
            ;;
        gpkg|geopackage)
            # GeoPackage options
            ogr_opts+=("-lco" "GEOMETRY_NAME=${geom_col}")
            ;;
    esac
    
    # Run ogr2ogr
    if ogr2ogr \
        "${ogr_opts[@]}" \
        "${output_file}" \
        "${ogr_conn}" \
        -sql "${sql}" \
        2>&1 | tee -a "${LOG_FILE}"; then
        
        # Check output file exists and has size > 0
        if [[ -f "${output_file}" && -s "${output_file}" ]]; then
            return 0
        elif [[ -d "${output_file}" ]]; then
            # Shapefile creates a directory sometimes
            return 0
        fi
    fi
    
    return 1
}

# Alternative: Export using SQL COPY to CSV + geometry as WKT
export_vector_sql_wkt() {
    local schema="$1"
    local table="$2"
    local geom_col="$3"
    local output_file="$4"
    
    info "Trying SQL/WKT export for ${schema}.${table}..."
    
    # Get all columns except geometry, then add geometry as WKT
    local columns_query="
    SELECT string_agg(
        CASE 
            WHEN column_name = '${geom_col}' THEN 'ST_AsText(\"${geom_col}\") as ${geom_col}_wkt'
            ELSE '\"' || column_name || '\"'
        END, ', '
    )
    FROM information_schema.columns
    WHERE table_schema = '${schema}' AND table_name = '${table}'
    "
    
    local columns
    columns=$(${PSQL_CMD} -c "${columns_query}" | tr -d ' ')
    
    if [[ -z "${columns}" ]]; then
        error "Could not get columns for ${schema}.${table}"
        return 1
    fi
    
    # Export as CSV with WKT geometry
    local csv_output="${output_file%.geojson}.csv"
    local export_query="COPY (SELECT ${columns} FROM \"${schema}\".\"${table}\") TO STDOUT WITH CSV HEADER"
    
    ${PSQL_CMD} -c "${export_query}" > "${csv_output}" 2>/dev/null
    
    if [[ -f "${csv_output}" && -s "${csv_output}" ]]; then
        info "Exported to CSV with WKT: ${csv_output}"
        # Note: This is a fallback, the GeoJSON conversion would need additional processing
        return 0
    fi
    
    return 1
}

# Alternative: Export as GeoJSON using SQL ST_AsGeoJSON
export_vector_sql_geojson() {
    local schema="$1"
    local table="$2"
    local geom_col="$3"
    local output_file="$4"
    
    info "Trying SQL/GeoJSON export for ${schema}.${table}..."
    
    # Get non-geometry columns for properties
    local props_query="
    SELECT string_agg(
        '\"' || column_name || '\", \"' || column_name || '\"',
        ', '
    )
    FROM information_schema.columns
    WHERE table_schema = '${schema}' 
      AND table_name = '${table}'
      AND column_name != '${geom_col}'
      AND data_type NOT IN ('geometry', 'geography')
    "
    
    local props_cols
    props_cols=$(${PSQL_CMD} -c "${props_query}" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Build GeoJSON FeatureCollection using SQL
    local geojson_query
    if [[ -n "${props_cols}" ]]; then
        geojson_query="
        SELECT json_build_object(
            'type', 'FeatureCollection',
            'features', COALESCE(json_agg(
                json_build_object(
                    'type', 'Feature',
                    'geometry', ST_AsGeoJSON(\"${geom_col}\")::json,
                    'properties', json_build_object(${props_cols})
                )
            ), '[]'::json)
        )::text
        FROM \"${schema}\".\"${table}\"
        WHERE \"${geom_col}\" IS NOT NULL
        "
    else
        geojson_query="
        SELECT json_build_object(
            'type', 'FeatureCollection',
            'features', COALESCE(json_agg(
                json_build_object(
                    'type', 'Feature',
                    'geometry', ST_AsGeoJSON(\"${geom_col}\")::json,
                    'properties', '{}'::json
                )
            ), '[]'::json)
        )::text
        FROM \"${schema}\".\"${table}\"
        WHERE \"${geom_col}\" IS NOT NULL
        "
    fi
    
    # Execute and save
    ${PSQL_CMD} -c "${geojson_query}" > "${output_file}" 2>/dev/null
    
    # Check if valid JSON was created
    if [[ -f "${output_file}" && -s "${output_file}" ]]; then
        # Basic validation - check it starts with {
        if head -c 1 "${output_file}" | grep -q '{'; then
            return 0
        fi
    fi
    
    return 1
}

# Export large tables in chunks (for memory constraints)
export_vector_chunked() {
    local schema="$1"
    local table="$2"
    local geom_col="$3"
    local output_dir="$4"
    local row_count="$5"
    
    local chunk_size=10000
    local chunks_dir="${output_dir}/${schema}_${table}_chunks"
    mkdir -p "${chunks_dir}"
    
    info "Exporting ${schema}.${table} in chunks (${row_count} rows)..."
    
    local offset=0
    local chunk_num=0
    local ext
    ext=$(get_extension)
    
    while [[ ${offset} -lt ${row_count} ]]; do
        chunk_num=$((chunk_num + 1))
        local chunk_file="${chunks_dir}/chunk_$(printf '%04d' ${chunk_num}).${ext}"
        
        # Skip if already exported
        if [[ -f "${chunk_file}" && -s "${chunk_file}" ]]; then
            offset=$((offset + chunk_size))
            continue
        fi
        
        info "  Exporting chunk ${chunk_num} (offset ${offset})..."
        
        local driver
        driver=$(get_driver)
        local ogr_conn="PG:host=${DB_HOST} port=${DB_PORT} dbname='${DB_NAME}' user='${DB_USER}' password='${DB_PASSWORD}'"
        local sql="SELECT * FROM \"${schema}\".\"${table}\" ORDER BY ctid LIMIT ${chunk_size} OFFSET ${offset}"
        
        ogr2ogr -f "${driver}" "${chunk_file}" "${ogr_conn}" -sql "${sql}" 2>&1 | tee -a "${LOG_FILE}" || true
        
        offset=$((offset + chunk_size))
    done
    
    # Check if we got any chunks
    local chunk_count
    chunk_count=$(find "${chunks_dir}" -name "*.${ext}" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ ${chunk_count} -gt 0 ]]; then
        info "Exported ${chunk_count} chunks to ${chunks_dir}"
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
    
    # Determine content type
    local content_type="application/octet-stream"
    case "${local_file}" in
        *.geojson|*.json) content_type="application/geo+json" ;;
        *.csv) content_type="text/csv" ;;
        *.gpkg) content_type="application/geopackage+sqlite3" ;;
    esac
    
    info "Uploading $(basename ${local_file}) (${file_size} bytes) to s3://${S3_BUCKET}/${s3_key}"
    
    if command -v aws >/dev/null 2>&1; then
        aws s3 cp "${local_file}" "s3://${S3_BUCKET}/${s3_key}" \
            --region "${AWS_REGION}" \
            --content-type "${content_type}" \
            2>&1 | tee -a "${LOG_FILE}" || return 1
    elif command -v s3cmd >/dev/null 2>&1; then
        s3cmd put "${local_file}" "s3://${S3_BUCKET}/${s3_key}" \
            --mime-type="${content_type}" \
            2>&1 | tee -a "${LOG_FILE}" || return 1
    else
        error "No S3 upload tool available"
        return 1
    fi
    
    return 0
}

# Upload shapefile (multiple files) to S3
upload_shapefile_to_s3() {
    local shp_file="$1"
    local s3_prefix="$2"
    
    if [[ -z "${S3_BUCKET}" ]]; then
        warn "S3_BUCKET not set, skipping upload"
        return 0
    fi
    
    local base_name="${shp_file%.shp}"
    local dir_name=$(dirname "${shp_file}")
    
    info "Uploading shapefile components to s3://${S3_BUCKET}/${s3_prefix}"
    
    # Upload all shapefile components
    for ext in shp shx dbf prj cpg sbn sbx; do
        local component="${base_name}.${ext}"
        if [[ -f "${component}" ]]; then
            local s3_key="${s3_prefix}$(basename ${component})"
            upload_to_s3 "${component}" "${s3_key}" || return 1
        fi
    done
    
    return 0
}

# Upload a directory of chunks to S3
upload_chunks_to_s3() {
    local chunks_dir="$1"
    local s3_prefix="$2"
    
    if [[ -z "${S3_BUCKET}" ]]; then
        warn "S3_BUCKET not set, skipping upload"
        return 0
    fi
    
    info "Uploading chunks directory to s3://${S3_BUCKET}/${s3_prefix}"
    
    if command -v aws >/dev/null 2>&1; then
        aws s3 sync "${chunks_dir}" "s3://${S3_BUCKET}/${s3_prefix}" \
            --region "${AWS_REGION}" \
            2>&1 | tee -a "${LOG_FILE}" || return 1
    elif command -v s3cmd >/dev/null 2>&1; then
        s3cmd sync "${chunks_dir}/" "s3://${S3_BUCKET}/${s3_prefix}" \
            2>&1 | tee -a "${LOG_FILE}" || return 1
    else
        error "No S3 upload tool available"
        return 1
    fi
    
    return 0
}

# Export all vectors
export_vectors() {
    if [[ ! -f "${CSV_FILE}" ]]; then
        warn "Vector list not found, running discovery first..."
        list_vectors
    fi
    
    info "Starting vector export..."
    
    local total=0
    local exported=0
    local skipped=0
    local failed=0
    
    local ext
    ext=$(get_extension)
    
    # Count total
    local total_count
    total_count=$(tail -n +2 "${CSV_FILE}" | wc -l | tr -d ' ')
    
    # Process each vector
    tail -n +2 "${CSV_FILE}" | while IFS=',' read -r schema table geom_col coord_dim srid geom_type row_count size_bytes; do
        [[ -z "${schema}" ]] && continue
        
        total=$((total + 1))
        local vector_id="${schema}.${table}"
        local filename="${schema}_${table}.${ext}"
        local output_file="${OUTPUT_DIR}/${filename}"
        local s3_key="${S3_PREFIX}${schema}/${table}.${ext}"
        
        echo ""
        info "[${total}/${total_count}] Processing ${vector_id} (${row_count} rows, ${geom_type})..."
        
        # Check if already exported
        if is_exported "${vector_id}" "${s3_key}"; then
            info "Skipping ${vector_id} - already exported"
            skipped=$((skipped + 1))
            continue
        fi
        
        local export_success=false
        
        # For very large tables, use chunked export
        if [[ ${row_count} -gt 100000 ]]; then
            warn "Large table (${row_count} rows), using chunked export..."
            if export_vector_chunked "${schema}" "${table}" "${geom_col}" "${OUTPUT_DIR}" "${row_count}"; then
                local chunks_dir="${OUTPUT_DIR}/${schema}_${table}_chunks"
                local chunks_s3_prefix="${S3_PREFIX}${schema}/${table}_chunks/"
                
                if upload_chunks_to_s3 "${chunks_dir}" "${chunks_s3_prefix}"; then
                    echo "${vector_id}" >> "${STATUS_FILE}"
                    exported=$((exported + 1))
                    continue
                fi
            fi
        fi
        
        # Try OGR export first (most efficient)
        if export_vector_ogr "${schema}" "${table}" "${geom_col}" "${output_file}"; then
            info "OGR export successful"
            export_success=true
        else
            warn "OGR export failed, trying SQL method..."
            
            # Try SQL GeoJSON export
            if [[ "${EXPORT_FORMAT}" == "geojson" ]]; then
                if export_vector_sql_geojson "${schema}" "${table}" "${geom_col}" "${output_file}"; then
                    info "SQL/GeoJSON export successful"
                    export_success=true
                fi
            fi
            
            # Fallback to CSV with WKT
            if [[ "${export_success}" != "true" ]]; then
                if export_vector_sql_wkt "${schema}" "${table}" "${geom_col}" "${output_file}"; then
                    info "SQL/WKT export successful (as CSV)"
                    export_success=true
                    # Update output file to CSV
                    output_file="${output_file%.${ext}}.csv"
                    s3_key="${S3_PREFIX}${schema}/${table}.csv"
                fi
            fi
        fi
        
        if [[ "${export_success}" == "true" ]]; then
            # Upload to S3
            if [[ "${EXPORT_FORMAT}" == "shapefile" || "${EXPORT_FORMAT}" == "shp" ]]; then
                # Shapefile needs special handling (multiple files)
                local shp_s3_prefix="${S3_PREFIX}${schema}/${table}/"
                if upload_shapefile_to_s3 "${output_file}" "${shp_s3_prefix}"; then
                    echo "${vector_id}" >> "${STATUS_FILE}"
                    exported=$((exported + 1))
                    info "Successfully exported and uploaded ${vector_id}"
                else
                    error "S3 upload failed for ${vector_id}"
                    echo "${vector_id}|upload_failed" >> "${FAILED_FILE}"
                    failed=$((failed + 1))
                fi
            else
                if upload_to_s3 "${output_file}" "${s3_key}"; then
                    echo "${vector_id}" >> "${STATUS_FILE}"
                    exported=$((exported + 1))
                    info "Successfully exported and uploaded ${vector_id}"
                else
                    error "S3 upload failed for ${vector_id}"
                    echo "${vector_id}|upload_failed" >> "${FAILED_FILE}"
                    failed=$((failed + 1))
                fi
            fi
        else
            error "All export methods failed for ${vector_id}"
            echo "${vector_id}|export_failed" >> "${FAILED_FILE}"
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    info "=========================================="
    info "Export complete!"
    info "  Total processed: ${total_count}"
    info "  Check ${STATUS_FILE} for exported vectors"
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
        echo "Total vectors discovered: ${total}"
        
        # Show summary by geometry type
        echo ""
        echo "By geometry type:"
        tail -n +2 "${CSV_FILE}" | cut -d',' -f6 | sort | uniq -c | sort -rn
    else
        echo "Vector list not created yet. Run: $0 list"
    fi
    
    if [[ -f "${STATUS_FILE}" ]]; then
        local exported
        exported=$(wc -l < "${STATUS_FILE}" | tr -d ' ')
        echo ""
        echo "Successfully exported: ${exported}"
    else
        echo "Successfully exported: 0"
    fi
    
    if [[ -f "${FAILED_FILE}" && -s "${FAILED_FILE}" ]]; then
        local failed
        failed=$(wc -l < "${FAILED_FILE}" | tr -d ' ')
        echo "Failed exports: ${failed}"
        echo ""
        echo "Failed vectors:"
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
    
    local ext
    ext=$(get_extension)
    
    while IFS='|' read -r vector_id reason; do
        [[ -z "${vector_id}" ]] && continue
        
        # Parse vector_id
        local schema table
        schema=$(echo "${vector_id}" | cut -d. -f1)
        table=$(echo "${vector_id}" | cut -d. -f2)
        
        # Get geometry column from CSV
        local geom_col
        geom_col=$(grep "^${schema},${table}," "${CSV_FILE}" | cut -d',' -f3)
        
        if [[ -z "${geom_col}" ]]; then
            warn "Could not find geometry column for ${vector_id}, skipping"
            echo "${vector_id}|no_geom_col" >> "${FAILED_FILE}"
            continue
        fi
        
        local filename="${schema}_${table}.${ext}"
        local output_file="${OUTPUT_DIR}/${filename}"
        local s3_key="${S3_PREFIX}${schema}/${table}.${ext}"
        
        info "Retrying ${vector_id}..."
        
        # Remove from status if present (force re-export)
        sed -i "/${vector_id}/d" "${STATUS_FILE}" 2>/dev/null || true
        
        local export_success=false
        
        if export_vector_ogr "${schema}" "${table}" "${geom_col}" "${output_file}"; then
            export_success=true
        elif [[ "${EXPORT_FORMAT}" == "geojson" ]]; then
            if export_vector_sql_geojson "${schema}" "${table}" "${geom_col}" "${output_file}"; then
                export_success=true
            fi
        fi
        
        if [[ "${export_success}" == "true" ]]; then
            if upload_to_s3 "${output_file}" "${s3_key}"; then
                echo "${vector_id}" >> "${STATUS_FILE}"
                info "Retry successful for ${vector_id}"
            else
                echo "${vector_id}|upload_failed" >> "${FAILED_FILE}"
            fi
        else
            echo "${vector_id}|export_failed" >> "${FAILED_FILE}"
        fi
    done < "${temp_failed}"
    
    rm -f "${temp_failed}"
    
    show_status
}

# Test OGR PostgreSQL driver
test_ogr() {
    info "Testing OGR PostgreSQL driver..."
    
    # Check if driver is available
    if ! ogrinfo --formats 2>/dev/null | grep -qi "PostgreSQL"; then
        error "OGR PostgreSQL driver not found!"
        error "You may need to rebuild GDAL/OGR with PostgreSQL support"
        return 1
    fi
    
    info "PostgreSQL driver is available"
    
    # Check export format driver
    local driver
    driver=$(get_driver)
    if ogrinfo --formats 2>/dev/null | grep -qi "${driver}"; then
        info "${driver} driver is available"
    else
        warn "${driver} driver may not be available"
    fi
    
    # Try to connect and list layers via OGR
    local ogr_conn="PG:host=${DB_HOST} port=${DB_PORT} dbname='${DB_NAME}' user='${DB_USER}' password='${DB_PASSWORD}'"
    
    info "Testing connection to database..."
    if ogrinfo "${ogr_conn}" 2>&1 | head -20; then
        info "OGR can connect to database"
        return 0
    else
        warn "OGR connection test had issues, but may still work"
        return 0
    fi
}

# Export a single table (for testing/manual export)
export_single() {
    local table_spec="$1"  # schema.table format
    
    if [[ -z "${table_spec}" || "${table_spec}" != *"."* ]]; then
        error "Usage: $0 single schema.table"
        exit 1
    fi
    
    local schema table
    schema=$(echo "${table_spec}" | cut -d. -f1)
    table=$(echo "${table_spec}" | cut -d. -f2)
    
    # Get geometry column
    local geom_query="
    SELECT f_geometry_column 
    FROM geometry_columns 
    WHERE f_table_schema = '${schema}' AND f_table_name = '${table}'
    LIMIT 1
    "
    local geom_col
    geom_col=$(${PSQL_CMD} -c "${geom_query}" | tr -d ' ')
    
    if [[ -z "${geom_col}" ]]; then
        error "Could not find geometry column for ${table_spec}"
        exit 1
    fi
    
    local ext
    ext=$(get_extension)
    local output_file="${OUTPUT_DIR}/${schema}_${table}.${ext}"
    
    info "Exporting ${table_spec} (geometry column: ${geom_col})..."
    
    if export_vector_ogr "${schema}" "${table}" "${geom_col}" "${output_file}"; then
        info "Export successful: ${output_file}"
    else
        warn "OGR export failed, trying SQL method..."
        if export_vector_sql_geojson "${schema}" "${table}" "${geom_col}" "${output_file}"; then
            info "Export successful: ${output_file}"
        else
            error "Export failed"
            exit 1
        fi
    fi
}

# Main
main() {
    local command="${1:-help}"
    
    case "${command}" in
        list)
            check_prereqs
            list_vectors
            ;;
        export)
            check_prereqs
            export_vectors
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
            test_ogr
            ;;
        single)
            check_prereqs
            export_single "${2:-}"
            ;;
        help|--help|-h)
            cat <<EOF
CartoDB Vector Export Script

Exports PostGIS vector tables to GeoJSON/Shapefile and uploads to S3.
Compatible with GDAL/OGR 1.11+ on Ubuntu 12.04.

Usage: $0 <command> [options]

Commands:
    list     Discover all vector tables and write to CSV
    export   Export vectors and upload to S3
    status   Show export status
    retry    Retry failed exports
    test     Test OGR PostgreSQL driver
    single   Export a single table: $0 single schema.table

Environment variables:
    DB_HOST       Database host (default: localhost)
    DB_PORT       Database port (default: 5432)
    DB_NAME       Database name (default: cartodb)
    DB_USER       Database user (default: postgres)
    DB_PASSWORD   Database password

    S3_BUCKET     S3 bucket name (required for upload)
    S3_PREFIX     S3 key prefix (default: cartodb-vectors/)
    AWS_DEFAULT_REGION  AWS region (default: us-east-1)

    EXPORT_FORMAT Export format: geojson, shapefile, gpkg (default: geojson)
    OUTPUT_DIR    Local output directory (default: ./vector_exports)

Examples:
    # Set up environment
    export DB_HOST=localhost DB_NAME=cartodb_user_db
    export DB_USER=postgres DB_PASSWORD=secret
    export S3_BUCKET=my-bucket S3_PREFIX=vectors/

    # Test OGR driver
    $0 test

    # List all vectors to CSV
    $0 list

    # Export as GeoJSON (default)
    $0 export

    # Export as Shapefile
    EXPORT_FORMAT=shapefile $0 export

    # Export a single table
    $0 single public.my_table

    # Check progress
    $0 status

    # Retry any failed exports
    $0 retry

Export Methods (tried in order):
    1. OGR ogr2ogr - Most efficient, uses PostgreSQL driver
    2. SQL ST_AsGeoJSON - Direct PostgreSQL export for GeoJSON
    3. SQL WKT - Fallback exports CSV with WKT geometry

Notes:
    - Export progress is saved, so you can stop and resume
    - Vectors already in S3 are skipped (unless you remove from status file)
    - Large tables (>100k rows) are exported in chunks automatically
    - GeoJSON is most portable; Shapefile has 2GB and field name limits
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