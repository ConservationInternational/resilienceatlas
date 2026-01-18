#!/bin/bash
#
# COG Conversion Manager
#
# Lists raw TIFFs in S3, checks which have been converted to COGs,
# and invokes Lambda to convert the remaining ones.
#
# Usage:
#   ./manage_cog_conversion.sh list       - List all raw TIFFs
#   ./manage_cog_conversion.sh status     - Show conversion status
#   ./manage_cog_conversion.sh convert    - Convert pending TIFFs
#   ./manage_cog_conversion.sh convert-one <key>  - Convert a single TIFF
#   ./manage_cog_conversion.sh deploy     - Deploy Lambda function
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# S3 configuration
S3_BUCKET="${S3_BUCKET:-}"
SOURCE_PREFIX="${SOURCE_PREFIX:-cartodb-rasters/}"
COG_PREFIX="${COG_PREFIX:-cartodb-cogs/}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_PROFILE="${AWS_PROFILE:-}"  # AWS credentials profile name

# Export AWS_PROFILE if set (AWS CLI uses this automatically)
if [[ -n "${AWS_PROFILE}" ]]; then
    export AWS_PROFILE
fi

# Lambda configuration
LAMBDA_FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-cog-converter}"
ECR_REPO_NAME="${ECR_REPO_NAME:-cog-converter}"
LAMBDA_MEMORY="${LAMBDA_MEMORY:-3008}"  # MB, needs enough for large TIFFs
LAMBDA_TIMEOUT="${LAMBDA_TIMEOUT:-900}"  # 15 minutes max

# Processing options
BATCH_SIZE="${BATCH_SIZE:-10}"  # TIFFs per Lambda invocation
COMPRESSION="${COMPRESSION:-LZW}"  # LZW, DEFLATE, ZSTD
PARALLEL_INVOCATIONS="${PARALLEL_INVOCATIONS:-5}"  # Concurrent Lambda calls
OVERWRITE="${OVERWRITE:-false}"
FILENAME_FILTER="${FILENAME_FILTER:-}"  # Regex to filter filenames (e.g., "^public_.*")
DRY_RUN="${DRY_RUN:-false}"  # Show what would run without executing

# Local directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/cog_status}"
LAMBDA_DIR="${SCRIPT_DIR}/lambda_function"

# Status files
TIFF_LIST="${OUTPUT_DIR}/raw_tiffs.txt"
COG_LIST="${OUTPUT_DIR}/existing_cogs.txt"
PENDING_LIST="${OUTPUT_DIR}/pending_conversions.txt"
COMPLETED_LIST="${OUTPUT_DIR}/completed_conversions.txt"
FAILED_LIST="${OUTPUT_DIR}/failed_conversions.txt"
LOG_FILE="${OUTPUT_DIR}/cog_conversion.log"

# =============================================================================
# Utility Functions
# =============================================================================

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "${LOG_FILE}"
}

info() {
    log "INFO: $*"
}

warn() {
    log "WARN: $*"
}

error() {
    log "ERROR: $*" >&2
}

check_requirements() {
    local missing=0
    
    for cmd in aws jq; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Required command not found: $cmd"
            missing=1
        fi
    done
    
    if [[ -z "${S3_BUCKET}" ]]; then
        error "S3_BUCKET environment variable not set"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

ensure_output_dir() {
    mkdir -p "${OUTPUT_DIR}"
}

# =============================================================================
# S3 Listing Functions
# =============================================================================

# List all raw TIFFs in source prefix
list_raw_tiffs() {
    info "Listing raw TIFFs in s3://${S3_BUCKET}/${SOURCE_PREFIX}..."
    
    aws s3api list-objects-v2 \
        --bucket "${S3_BUCKET}" \
        --prefix "${SOURCE_PREFIX}" \
        --query "Contents[?ends_with(Key, '.tif') || ends_with(Key, '.tiff')].{Key: Key, Size: Size}" \
        --output json \
        2>/dev/null | jq -r '.[] | "\(.Key)\t\(.Size)"' > "${TIFF_LIST}.unfiltered" || {
            # Handle empty results
            echo -n > "${TIFF_LIST}.unfiltered"
        }
    
    # Apply filename filter if specified
    if [[ -n "${FILENAME_FILTER}" ]]; then
        info "Applying filename filter: ${FILENAME_FILTER}"
        while IFS=$'\t' read -r key size; do
            [[ -z "${key}" ]] && continue
            local filename
            filename=$(basename "${key}")
            if echo "${filename}" | grep -qE "${FILENAME_FILTER}"; then
                echo -e "${key}\t${size}"
            fi
        done < "${TIFF_LIST}.unfiltered" > "${TIFF_LIST}"
        rm -f "${TIFF_LIST}.unfiltered"
    else
        mv "${TIFF_LIST}.unfiltered" "${TIFF_LIST}"
    fi
    
    local count
    count=$(wc -l < "${TIFF_LIST}" | tr -d ' ')
    info "Found ${count} raw TIFFs${FILENAME_FILTER:+ (filtered)}"
    
    echo "${count}"
}

# List all existing COGs in destination prefix
list_existing_cogs() {
    info "Listing existing COGs in s3://${S3_BUCKET}/${COG_PREFIX}..."
    
    aws s3api list-objects-v2 \
        --bucket "${S3_BUCKET}" \
        --prefix "${COG_PREFIX}" \
        --query "Contents[?ends_with(Key, '.tif') || ends_with(Key, '.tiff')].Key" \
        --output text \
        2>/dev/null | tr '\t' '\n' | grep -v '^None$' > "${COG_LIST}" || {
            echo -n > "${COG_LIST}"
        }
    
    local count
    count=$(wc -l < "${COG_LIST}" | tr -d ' ')
    info "Found ${count} existing COGs"
    
    echo "${count}"
}

# Determine which TIFFs need conversion
find_pending_conversions() {
    info "Finding TIFFs pending conversion..."
    
    # Clear pending list
    > "${PENDING_LIST}"
    
    while IFS=$'\t' read -r source_key size; do
        [[ -z "${source_key}" ]] && continue
        
        # Build expected COG key
        local filename
        filename=$(basename "${source_key}")
        local stem="${filename%.*}"
        local cog_key="${COG_PREFIX}${stem}_cog.tif"
        
        # Check if COG exists
        if ! grep -qF "${cog_key}" "${COG_LIST}" 2>/dev/null; then
            echo -e "${source_key}\t${size}" >> "${PENDING_LIST}"
        fi
    done < "${TIFF_LIST}"
    
    local count
    count=$(wc -l < "${PENDING_LIST}" | tr -d ' ')
    info "Found ${count} TIFFs pending conversion"
    
    echo "${count}"
}

# =============================================================================
# Lambda Deployment
# =============================================================================

deploy_lambda() {
    info "Deploying COG conversion Lambda function..."
    
    # Get AWS account ID
    local account_id
    account_id=$(aws sts get-caller-identity --query Account --output text)
    
    local ecr_uri="${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
    
    # Create ECR repository if not exists
    info "Creating ECR repository..."
    aws ecr describe-repositories --repository-names "${ECR_REPO_NAME}" 2>/dev/null || \
        aws ecr create-repository --repository-name "${ECR_REPO_NAME}" --image-scanning-configuration scanOnPush=true
    
    # Login to ECR
    info "Logging into ECR..."
    aws ecr get-login-password --region "${AWS_REGION}" | \
        docker login --username AWS --password-stdin "${account_id}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    
    # Build Docker image
    info "Building Docker image..."
    docker build -t "${ECR_REPO_NAME}:latest" "${LAMBDA_DIR}"
    
    # Tag and push
    info "Pushing image to ECR..."
    docker tag "${ECR_REPO_NAME}:latest" "${ecr_uri}:latest"
    docker push "${ecr_uri}:latest"
    
    # Create or update Lambda function
    info "Creating/updating Lambda function..."
    
    # Create execution role if not exists
    local role_arn
    role_arn=$(create_lambda_role)
    
    # Check if function exists
    if aws lambda get-function --function-name "${LAMBDA_FUNCTION_NAME}" 2>/dev/null; then
        # Update existing function
        info "Updating existing Lambda function..."
        aws lambda update-function-code \
            --function-name "${LAMBDA_FUNCTION_NAME}" \
            --image-uri "${ecr_uri}:latest" \
            --publish
        
        # Wait for update to complete
        aws lambda wait function-updated --function-name "${LAMBDA_FUNCTION_NAME}"
        
        # Update configuration
        aws lambda update-function-configuration \
            --function-name "${LAMBDA_FUNCTION_NAME}" \
            --memory-size "${LAMBDA_MEMORY}" \
            --timeout "${LAMBDA_TIMEOUT}" \
            --ephemeral-storage Size=10240
    else
        # Create new function
        info "Creating new Lambda function..."
        aws lambda create-function \
            --function-name "${LAMBDA_FUNCTION_NAME}" \
            --package-type Image \
            --code ImageUri="${ecr_uri}:latest" \
            --role "${role_arn}" \
            --memory-size "${LAMBDA_MEMORY}" \
            --timeout "${LAMBDA_TIMEOUT}" \
            --ephemeral-storage Size=10240
        
        # Wait for function to be active
        aws lambda wait function-active --function-name "${LAMBDA_FUNCTION_NAME}"
    fi
    
    info "Lambda function deployed successfully: ${LAMBDA_FUNCTION_NAME}"
}

create_lambda_role() {
    local role_name="${LAMBDA_FUNCTION_NAME}-role"
    
    # Check if role exists
    local role_arn
    role_arn=$(aws iam get-role --role-name "${role_name}" --query Role.Arn --output text 2>/dev/null) || {
        info "Creating IAM role for Lambda..."
        
        # Create trust policy
        local trust_policy='{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }'
        
        aws iam create-role \
            --role-name "${role_name}" \
            --assume-role-policy-document "${trust_policy}" \
            --query Role.Arn --output text
        
        # Attach basic Lambda execution policy
        aws iam attach-role-policy \
            --role-name "${role_name}" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
        
        # Create and attach S3 access policy
        local s3_policy='{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": [
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:HeadObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::*"
                ]
            }]
        }'
        
        aws iam put-role-policy \
            --role-name "${role_name}" \
            --policy-name "S3Access" \
            --policy-document "${s3_policy}"
        
        # Wait for role to propagate
        sleep 10
        
        role_arn=$(aws iam get-role --role-name "${role_name}" --query Role.Arn --output text)
    }
    
    echo "${role_arn}"
}

# =============================================================================
# Lambda Invocation
# =============================================================================

# Invoke Lambda for a single TIFF
invoke_lambda_single() {
    local source_key="$1"
    
    local payload
    payload=$(jq -n \
        --arg bucket "${S3_BUCKET}" \
        --arg key "${source_key}" \
        --arg dest_bucket "${S3_BUCKET}" \
        --arg dest_prefix "${COG_PREFIX}" \
        --arg compression "${COMPRESSION}" \
        --argjson overwrite "${OVERWRITE}" \
        '{
            source_bucket: $bucket,
            source_key: $key,
            dest_bucket: $dest_bucket,
            dest_prefix: $dest_prefix,
            compression: $compression,
            overwrite: $overwrite
        }')
    
    info "Invoking Lambda for: ${source_key}"
    
    local response
    response=$(aws lambda invoke \
        --function-name "${LAMBDA_FUNCTION_NAME}" \
        --payload "${payload}" \
        --cli-binary-format raw-in-base64-out \
        /dev/stdout 2>/dev/null)
    
    echo "${response}"
}

# Invoke Lambda for a batch of TIFFs
invoke_lambda_batch() {
    local -a keys=("$@")
    
    # Build batch payload
    local batch_items
    batch_items=$(printf '%s\n' "${keys[@]}" | jq -R -s 'split("\n") | map(select(length > 0)) | map({source_key: .})')
    
    local payload
    payload=$(jq -n \
        --arg bucket "${S3_BUCKET}" \
        --arg dest_bucket "${S3_BUCKET}" \
        --arg dest_prefix "${COG_PREFIX}" \
        --arg compression "${COMPRESSION}" \
        --argjson overwrite "${OVERWRITE}" \
        --argjson batch "${batch_items}" \
        '{
            source_bucket: $bucket,
            dest_bucket: $dest_bucket,
            dest_prefix: $dest_prefix,
            compression: $compression,
            overwrite: $overwrite,
            batch: $batch
        }')
    
    info "Invoking Lambda for batch of ${#keys[@]} TIFFs..."
    
    local response
    response=$(aws lambda invoke \
        --function-name "${LAMBDA_FUNCTION_NAME}" \
        --payload "${payload}" \
        --cli-binary-format raw-in-base64-out \
        /dev/stdout 2>/dev/null)
    
    echo "${response}"
}

# Process all pending conversions
convert_all_pending() {
    local pending_count
    pending_count=$(wc -l < "${PENDING_LIST}" | tr -d ' ')
    
    if [[ "${pending_count}" -eq 0 ]]; then
        info "No pending conversions"
        return 0
    fi
    
    # Dry-run mode - just show what would be processed
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo ""
        echo "=========================================="
        echo "  DRY RUN - No changes will be made"
        echo "=========================================="
        echo "  Would process: ${pending_count} TIFFs"
        echo "  Batch size: ${BATCH_SIZE}"
        echo "  Parallel invocations: ${PARALLEL_INVOCATIONS}"
        echo "  Compression: ${COMPRESSION}"
        echo "  Overwrite: ${OVERWRITE}"
        [[ -n "${FILENAME_FILTER}" ]] && echo "  Filename filter: ${FILENAME_FILTER}"
        echo ""
        echo "Files that would be converted:"
        echo "----------------------------------------"
        cat "${PENDING_LIST}" | while IFS=$'\t' read -r key size; do
            local filename
            filename=$(basename "${key}")
            local stem="${filename%.*}"
            local cog_key="${COG_PREFIX}${stem}_cog.tif"
            local size_mb=$((size / 1024 / 1024))
            echo "  ${key} (${size_mb} MB) -> ${cog_key}"
        done
        echo "----------------------------------------"
        echo ""
        echo "To execute, run without DRY_RUN=true"
        return 0
    fi
    
    info "Processing ${pending_count} pending conversions..."
    info "Batch size: ${BATCH_SIZE}, Parallel invocations: ${PARALLEL_INVOCATIONS}"
    
    local batch=()
    local batch_num=0
    local total_batches=$(( (pending_count + BATCH_SIZE - 1) / BATCH_SIZE ))
    
    # Create temp dir for batch results
    local results_dir
    results_dir=$(mktemp -d)
    trap "rm -rf ${results_dir}" EXIT
    
    while IFS=$'\t' read -r source_key size; do
        [[ -z "${source_key}" ]] && continue
        
        batch+=("${source_key}")
        
        # Process batch when full
        if [[ ${#batch[@]} -ge ${BATCH_SIZE} ]]; then
            batch_num=$((batch_num + 1))
            process_batch "${batch_num}" "${total_batches}" "${results_dir}" "${batch[@]}" &
            batch=()
            
            # Limit parallel invocations
            while [[ $(jobs -r | wc -l) -ge ${PARALLEL_INVOCATIONS} ]]; do
                sleep 1
            done
        fi
    done < "${PENDING_LIST}"
    
    # Process remaining batch
    if [[ ${#batch[@]} -gt 0 ]]; then
        batch_num=$((batch_num + 1))
        process_batch "${batch_num}" "${total_batches}" "${results_dir}" "${batch[@]}" &
    fi
    
    # Wait for all batches to complete
    wait
    
    # Aggregate results
    info "Aggregating results..."
    aggregate_results "${results_dir}"
    
    # Show summary
    show_conversion_summary
}

process_batch() {
    local batch_num="$1"
    local total_batches="$2"
    local results_dir="$3"
    shift 3
    local keys=("$@")
    
    info "Processing batch ${batch_num}/${total_batches} (${#keys[@]} TIFFs)..."
    
    local response
    response=$(invoke_lambda_batch "${keys[@]}")
    
    # Save response to file
    echo "${response}" > "${results_dir}/batch_${batch_num}.json"
    
    # Parse response and update status files
    local body
    body=$(echo "${response}" | jq -r '.body // .')
    
    if echo "${body}" | jq -e '.results' >/dev/null 2>&1; then
        # Batch response
        echo "${body}" | jq -r '.results[] | select(.status == "success") | .source_key' >> "${COMPLETED_LIST}.tmp"
        echo "${body}" | jq -r '.results[] | select(.status == "error") | "\(.source_key)\t\(.error)"' >> "${FAILED_LIST}.tmp"
    else
        # Single response
        local status
        status=$(echo "${body}" | jq -r '.status // "unknown"')
        local source_key
        source_key=$(echo "${body}" | jq -r '.source_key // "unknown"')
        
        if [[ "${status}" == "success" ]]; then
            echo "${source_key}" >> "${COMPLETED_LIST}.tmp"
        elif [[ "${status}" == "error" ]]; then
            local err
            err=$(echo "${body}" | jq -r '.error // "unknown error"')
            echo -e "${source_key}\t${err}" >> "${FAILED_LIST}.tmp"
        fi
    fi
    
    info "Batch ${batch_num}/${total_batches} complete"
}

aggregate_results() {
    local results_dir="$1"
    
    # Append temp files to main status files
    if [[ -f "${COMPLETED_LIST}.tmp" ]]; then
        cat "${COMPLETED_LIST}.tmp" >> "${COMPLETED_LIST}"
        rm -f "${COMPLETED_LIST}.tmp"
    fi
    
    if [[ -f "${FAILED_LIST}.tmp" ]]; then
        cat "${FAILED_LIST}.tmp" >> "${FAILED_LIST}"
        rm -f "${FAILED_LIST}.tmp"
    fi
    
    # Sort and dedupe
    if [[ -f "${COMPLETED_LIST}" ]]; then
        sort -u "${COMPLETED_LIST}" -o "${COMPLETED_LIST}"
    fi
    if [[ -f "${FAILED_LIST}" ]]; then
        sort -u "${FAILED_LIST}" -o "${FAILED_LIST}"
    fi
}

show_conversion_summary() {
    local total_raw=0
    local total_cogs=0
    local completed=0
    local failed=0
    
    [[ -f "${TIFF_LIST}" ]] && total_raw=$(wc -l < "${TIFF_LIST}" | tr -d ' ')
    [[ -f "${COG_LIST}" ]] && total_cogs=$(wc -l < "${COG_LIST}" | tr -d ' ')
    [[ -f "${COMPLETED_LIST}" ]] && completed=$(wc -l < "${COMPLETED_LIST}" | tr -d ' ')
    [[ -f "${FAILED_LIST}" ]] && failed=$(wc -l < "${FAILED_LIST}" | tr -d ' ')
    
    echo ""
    echo "=========================================="
    echo "  COG Conversion Summary"
    echo "=========================================="
    echo "  Raw TIFFs:        ${total_raw}"
    echo "  Existing COGs:    ${total_cogs}"
    echo "  Newly converted:  ${completed}"
    echo "  Failed:           ${failed}"
    echo "  Pending:          $((total_raw - total_cogs - completed))"
    echo "=========================================="
    echo ""
}

# =============================================================================
# Commands
# =============================================================================

cmd_list() {
    check_requirements
    ensure_output_dir
    
    list_raw_tiffs
    
    echo ""
    echo "Raw TIFFs listed in: ${TIFF_LIST}"
    echo ""
    echo "First 10 entries:"
    head -10 "${TIFF_LIST}"
}

cmd_status() {
    check_requirements
    ensure_output_dir
    
    list_raw_tiffs >/dev/null
    list_existing_cogs >/dev/null
    find_pending_conversions >/dev/null
    
    show_conversion_summary
    
    if [[ -f "${PENDING_LIST}" ]]; then
        local pending
        pending=$(wc -l < "${PENDING_LIST}" | tr -d ' ')
        if [[ "${pending}" -gt 0 ]]; then
            echo "First 10 pending:"
            head -10 "${PENDING_LIST}" | cut -f1
            echo ""
        fi
    fi
}

cmd_convert() {
    check_requirements
    ensure_output_dir
    
    # Refresh lists
    list_raw_tiffs >/dev/null
    list_existing_cogs >/dev/null
    find_pending_conversions >/dev/null
    
    # Check Lambda exists
    if ! aws lambda get-function --function-name "${LAMBDA_FUNCTION_NAME}" >/dev/null 2>&1; then
        error "Lambda function '${LAMBDA_FUNCTION_NAME}' not found. Run: $0 deploy"
        exit 1
    fi
    
    convert_all_pending
}

cmd_convert_one() {
    local source_key="$1"
    
    check_requirements
    ensure_output_dir
    
    if [[ -z "${source_key}" ]]; then
        error "Usage: $0 convert-one <s3-key>"
        exit 1
    fi
    
    # Check Lambda exists
    if ! aws lambda get-function --function-name "${LAMBDA_FUNCTION_NAME}" >/dev/null 2>&1; then
        error "Lambda function '${LAMBDA_FUNCTION_NAME}' not found. Run: $0 deploy"
        exit 1
    fi
    
    local response
    response=$(invoke_lambda_single "${source_key}")
    
    echo "${response}" | jq .
}

cmd_deploy() {
    check_requirements
    
    # Check Docker
    if ! command -v docker &>/dev/null; then
        error "Docker is required for deployment"
        exit 1
    fi
    
    deploy_lambda
}

cmd_help() {
    cat <<EOF
COG Conversion Manager

Manages conversion of raw GeoTIFFs to Cloud-Optimized GeoTIFFs (COGs)
using AWS Lambda with GDAL 3.9.

Usage: $0 <command> [options]

Commands:
    list          List all raw TIFFs in source S3 prefix
    status        Show conversion status (raw, converted, pending)
    convert       Convert all pending TIFFs to COGs
    convert-one   Convert a single TIFF: $0 convert-one <s3-key>
    deploy        Deploy Lambda function to AWS
    help          Show this help message

Environment Variables:
    S3_BUCKET               S3 bucket name (required)
    SOURCE_PREFIX           S3 prefix for raw TIFFs (default: cartodb-rasters/)
    COG_PREFIX              S3 prefix for COGs (default: cartodb-cogs/)
    AWS_REGION              AWS region (default: us-east-1)
    AWS_PROFILE             AWS credentials profile name (default: none, uses default)

    LAMBDA_FUNCTION_NAME    Lambda function name (default: cog-converter)
    LAMBDA_MEMORY           Lambda memory in MB (default: 3008)
    LAMBDA_TIMEOUT          Lambda timeout in seconds (default: 900)

    BATCH_SIZE              TIFFs per Lambda invocation (default: 10)
    PARALLEL_INVOCATIONS    Concurrent Lambda calls (default: 5)
    COMPRESSION             COG compression: LZW, DEFLATE, ZSTD (default: LZW)
    OVERWRITE               Overwrite existing COGs: true/false (default: false)
    
    FILENAME_FILTER         Regex to filter filenames (default: none)
                            Examples: "^public_" ".*_2024.*" "africa|asia"
    DRY_RUN                 Show what would run without executing (default: false)

Examples:
    # Set up environment
    export S3_BUCKET=my-bucket
    export SOURCE_PREFIX=cartodb-rasters/
    export COG_PREFIX=cartodb-cogs/

    # Deploy Lambda (first time only)
    $0 deploy

    # Check current status
    $0 status

    # Test mode - see what would be converted without running
    DRY_RUN=true $0 convert

    # Convert all pending TIFFs
    $0 convert

    # Convert only files matching a pattern
    FILENAME_FILTER="^public_" $0 convert
    FILENAME_FILTER="africa|asia" $0 convert
    FILENAME_FILTER=".*_2024.*\\.tif$" $0 convert

    # Dry run with filter - preview filtered files
    DRY_RUN=true FILENAME_FILTER="^schema1_" $0 convert

    # Convert a single file
    $0 convert-one cartodb-rasters/public_my_raster.tif

    # Use ZSTD compression (better ratio)
    COMPRESSION=ZSTD $0 convert

Output Files:
    ${OUTPUT_DIR}/
    ├── raw_tiffs.txt            # All raw TIFFs found (after filtering)
    ├── existing_cogs.txt        # Existing COGs in destination
    ├── pending_conversions.txt  # TIFFs awaiting conversion
    ├── completed_conversions.txt # Successfully converted
    ├── failed_conversions.txt   # Failed with error message
    └── cog_conversion.log       # Detailed log

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
            cmd_list
            ;;
        status)
            cmd_status
            ;;
        convert)
            cmd_convert
            ;;
        convert-one)
            cmd_convert_one "$@"
            ;;
        deploy)
            cmd_deploy
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            error "Unknown command: ${command}"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
