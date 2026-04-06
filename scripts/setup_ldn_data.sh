#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# setup_ldn_data.sh
#
# Downloads LDN (Land Degradation Neutrality) datasets and
# geoBoundaries GeoPackage files from the trends.earth-private S3
# bucket, then runs the existing rake tasks to import boundaries
# and dissolve LDN geometries, and finally seeds the LDN scope.
#
# Automatically detects the environment:
#   - Deployed (staging/production): uses running Swarm containers,
#     detected via .env.staging or .env.production in the working dir.
#   - Development: uses docker-compose.dev.yml.
#
# Prerequisites:
#   - AWS CLI configured with access to the trends.earth-private bucket
#   - Docker available
#
# Usage:
#   ./scripts/setup_ldn_data.sh [--profile <aws-profile>] [--skip-download] [--skip-boundaries]
#
# Environment variables:
#   LDN_DATA_DIR         — Local directory for LDN data (default: working dir)
#   GEOBOUNDARIES_DIR    — Local directory for boundary GPKGs (default: /tmp/geoboundaries)
# ──────────────────────────────────────────────────────────────

set -euo pipefail

# ── Defaults ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

S3_BUCKET="trends.earth-private"
S3_PREFIX="counterbalancing"
S3_INPUTS_PREFIX="${S3_PREFIX}/land_type/inputs"

LDN_DATA_DIR="${LDN_DATA_DIR:-$REPO_ROOT}"
GEOBOUNDARIES_DIR="${GEOBOUNDARIES_DIR:-/tmp/geoboundaries}"

AWS_PROFILE_ARG=""
SKIP_DOWNLOAD=false
SKIP_BOUNDARIES=false

# Runtime mode — set by detect_mode()
MODE=""            # "dev" or "deployed"
STACK_NAME=""      # e.g. "resilienceatlas-staging"
BACKEND_CONTAINER="" # container ID for deployed mode

# ── Parse arguments ──
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      AWS_PROFILE_ARG="--profile $2"
      shift 2
      ;;
    --skip-download)
      SKIP_DOWNLOAD=true
      shift
      ;;
    --skip-boundaries)
      SKIP_BOUNDARIES=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--profile <aws-profile>] [--skip-download] [--skip-boundaries]"
      echo ""
      echo "Options:"
      echo "  --profile <name>   AWS CLI profile name"
      echo "  --skip-download    Skip S3 downloads (use existing local files)"
      echo "  --skip-boundaries  Skip boundary import"
      echo ""
      echo "Environment:"
      echo "  LDN_DATA_DIR       Local dir for LDN data (default: repo root / working dir)"
      echo "  GEOBOUNDARIES_DIR  Local dir for boundary GPKGs (default: /tmp/geoboundaries)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ── Helper functions ──

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

check_aws_cli() {
  if ! command -v aws &>/dev/null; then
    error "AWS CLI is not installed. Install it first: https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  fi
  # Verify access to the bucket
  if ! aws s3 ls "s3://${S3_BUCKET}/" $AWS_PROFILE_ARG &>/dev/null; then
    error "Cannot access s3://${S3_BUCKET}/. Check your AWS credentials and permissions."
  fi
  ok "AWS CLI access verified for s3://${S3_BUCKET}/"
}

check_docker() {
  if ! command -v docker &>/dev/null; then
    error "Docker is not installed."
  fi
  ok "Docker available"
}

# ── Environment detection ──
# Detect whether we're on a deployed server (Swarm) or in local dev.
# Checks (in order):
#   1. .env.staging / .env.production files in the app directory
#   2. Running Docker Swarm stacks named resilienceatlas-staging/production
#   3. Falls back to dev mode (docker-compose.dev.yml)

detect_mode() {
  local env=""

  # Check for .env files
  if [[ -f "$REPO_ROOT/.env.staging" ]]; then
    env="staging"
  elif [[ -f "$REPO_ROOT/.env.production" ]]; then
    env="production"
  fi

  # If no .env file, check for running Swarm stacks
  if [[ -z "$env" ]]; then
    if docker service ls 2>/dev/null | grep -q "resilienceatlas-staging_backend"; then
      env="staging"
    elif docker service ls 2>/dev/null | grep -q "resilienceatlas-production_backend"; then
      env="production"
    fi
  fi

  # If no .env and no Swarm, check if we're in a deployed directory
  if [[ -z "$env" ]]; then
    case "$REPO_ROOT" in
      */resilienceatlas-staging*)  env="staging" ;;
      */resilienceatlas-production*) env="production" ;;
    esac
  fi

  if [[ -n "$env" ]]; then
    MODE="deployed"
    STACK_NAME="resilienceatlas-${env}"
    info "Detected deployed environment: ${env}"

    # Find the running backend container
    BACKEND_CONTAINER=$(docker ps --filter "name=${STACK_NAME}_backend" --format "{{.ID}}" 2>/dev/null | head -1)
    if [[ -z "$BACKEND_CONTAINER" ]]; then
      error "No running backend container found for stack ${STACK_NAME}. Is the stack deployed?"
    fi
    ok "Backend container: $BACKEND_CONTAINER"
  else
    MODE="dev"
    info "Detected development environment"
    if ! docker compose version &>/dev/null; then
      error "docker compose is not available (required for dev mode)."
    fi
  fi
}

# Run a command in the backend container.
# In deployed mode: docker exec on the running container.
# In dev mode: docker compose run with optional volume mounts.
backend_exec() {
  local env_args=()
  local vol_args=()
  local cmd_args=()
  local parsing_opts=true

  # Parse -e and -v flags, collect the rest as the command
  while [[ $# -gt 0 ]]; do
    if $parsing_opts; then
      case "$1" in
        -e)
          env_args+=("-e" "$2")
          shift 2
          ;;
        -v)
          vol_args+=("-v" "$2")
          shift 2
          ;;
        --)
          parsing_opts=false
          shift
          ;;
        *)
          parsing_opts=false
          cmd_args+=("$1")
          shift
          ;;
      esac
    else
      cmd_args+=("$1")
      shift
    fi
  done

  if [[ "$MODE" == "deployed" ]]; then
    # docker exec: env vars work, but volumes don't — files must be
    # docker-cp'd into the container before calling this.
    docker exec \
      ${env_args[@]+"${env_args[@]}"} \
      "$BACKEND_CONTAINER" "${cmd_args[@]}"
  else
    docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
      ${env_args[@]+"${env_args[@]}"} \
      ${vol_args[@]+"${vol_args[@]}"} \
      backend "${cmd_args[@]}"
  fi
}

# ── Productivity modes and their S3 folders ──
# S3 layout: s3://trends.earth-private/counterbalancing/{mode_s3_folder}/
#   Each folder contains TIFs, GPKGs, CSVs, JSONs, and XLSX files

declare -A MODE_S3_FOLDERS=(
  ["Trends.Earth"]="TE"
  ["FAO-WOCAT"]="FAO-WOCAT"
  ["JRC"]="JRC"
)

# Only the country_ecoregion GPKG is needed per mode — it's used by
# rake ldn:dissolve_geometries and seed.rb to import geometries + stats.
# TIF files are served by TiTiler directly from S3 at runtime and do NOT
# need to be downloaded locally.

# ──────────────────────────────────────────────────────────────
# Step 1: Download geoBoundaries GPKG files from S3
# ──────────────────────────────────────────────────────────────

download_boundaries() {
  info "Downloading geoBoundaries GPKG files..."
  mkdir -p "$GEOBOUNDARIES_DIR"

  local BOUNDARY_FILES=(
    "geoBoundariesCGAZ_ADM0.gpkg"
    "geoBoundariesCGAZ_ADM1.gpkg"
    "geoBoundariesCGAZ_ADM2.gpkg"
  )

  for f in "${BOUNDARY_FILES[@]}"; do
    local s3_path="s3://${S3_BUCKET}/${S3_INPUTS_PREFIX}/${f}"
    local local_path="${GEOBOUNDARIES_DIR}/${f}"

    if [[ -f "$local_path" ]]; then
      info "  Already exists: $local_path (skipping)"
    else
      info "  Downloading: $s3_path → $local_path"
      aws s3 cp "$s3_path" "$local_path" $AWS_PROFILE_ARG
    fi
  done

  ok "Boundary GPKG files ready in $GEOBOUNDARIES_DIR"
}

# ──────────────────────────────────────────────────────────────
# Step 2: Download LDN datasets from S3
# ──────────────────────────────────────────────────────────────

download_ldn_datasets() {
  info "Downloading LDN counterbalancing GPKG files..."
  mkdir -p "$LDN_DATA_DIR"

  local missing=0

  for mode_name in "${!MODE_S3_FOLDERS[@]}"; do
    local s3_folder="${MODE_S3_FOLDERS[$mode_name]}"
    local s3_base="s3://${S3_BUCKET}/${S3_PREFIX}/${s3_folder}"

    info "  Mode: $mode_name (s3 folder: $s3_folder)"

    # Only the country_ecoregion GPKG is needed (dissolve_geometries + seed)
    local gpkg="TrendsEarth_LDN_2000-2023_${mode_name}_country_ecoregion_land_types.gpkg"
    download_file "$s3_base/${gpkg}" "${LDN_DATA_DIR}/${gpkg}"

    if [[ ! -f "${LDN_DATA_DIR}/${gpkg}" ]]; then
      missing=$((missing + 1))
    fi
  done

  if [[ $missing -gt 0 ]]; then
    warn "$missing GPKG file(s) missing. The GPKG files may not be on S3 yet."
    warn "Upload them from your local machine with:"
    for mode_name in "${!MODE_S3_FOLDERS[@]}"; do
      local s3_folder="${MODE_S3_FOLDERS[$mode_name]}"
      local gpkg="TrendsEarth_LDN_2000-2023_${mode_name}_country_ecoregion_land_types.gpkg"
      if [[ ! -f "${LDN_DATA_DIR}/${gpkg}" ]]; then
        warn "  aws s3 cp ${gpkg} s3://${S3_BUCKET}/${S3_PREFIX}/${s3_folder}/${gpkg}"
      fi
    done
    error "Cannot continue without GPKG files. Upload them to S3 and re-run."
  fi

  ok "LDN GPKG files ready in $LDN_DATA_DIR"
}

download_file() {
  local s3_path="$1"
  local local_path="$2"

  if [[ -f "$local_path" ]]; then
    info "    Already exists: $(basename "$local_path") (skipping)"
  else
    info "    Downloading: $(basename "$local_path")"
    if ! aws s3 cp "$s3_path" "$local_path" $AWS_PROFILE_ARG 2>/dev/null; then
      warn "    Not found on S3: $(basename "$local_path") — skipping"
    fi
  fi
}

# ──────────────────────────────────────────────────────────────
# Step 3: Import boundaries via rake task
# ──────────────────────────────────────────────────────────────

import_boundaries() {
  info "Importing geoBoundaries into database..."

  if [[ "$MODE" == "deployed" ]]; then
    # Copy GPKGs into the running container, then exec rake
    docker exec "$BACKEND_CONTAINER" mkdir -p /data/geoboundaries
    for f in geoBoundariesCGAZ_ADM0.gpkg geoBoundariesCGAZ_ADM1.gpkg geoBoundariesCGAZ_ADM2.gpkg; do
      info "  Copying $f into container..."
      docker cp "${GEOBOUNDARIES_DIR}/${f}" "${BACKEND_CONTAINER}:/data/geoboundaries/${f}"
    done
    backend_exec -- bundle exec rake boundaries:import
  else
    info "  Starting database (if not already running)..."
    docker compose -f "$REPO_ROOT/docker-compose.dev.yml" up -d db
    info "  Waiting for database to be ready..."
    sleep 5
    backend_exec -v "${GEOBOUNDARIES_DIR}:/data/geoboundaries:ro" \
      -- bundle exec rake boundaries:import
  fi

  ok "Boundaries imported"
  backend_exec -- bundle exec rake boundaries:status
}

# ──────────────────────────────────────────────────────────────
# Step 4: Dissolve LDN geometries
# ──────────────────────────────────────────────────────────────

dissolve_ldn_geometries() {
  info "Dissolving LDN geometries..."

  if [[ "$MODE" == "deployed" ]]; then
    copy_ldn_data_to_container
    backend_exec -e "LDN_DATA_DIR=/data/ldn" \
      -- bundle exec rake ldn:dissolve_geometries
  else
    backend_exec -e "LDN_DATA_DIR=/data/ldn" -v "${LDN_DATA_DIR}:/data/ldn:ro" \
      -- bundle exec rake ldn:dissolve_geometries
  fi

  ok "LDN geometries dissolved"
  backend_exec -- bundle exec rake ldn:dissolve_status
}

# ──────────────────────────────────────────────────────────────
# Step 5: Run LDN seed
# ──────────────────────────────────────────────────────────────

seed_ldn_scope() {
  info "Seeding LDN site scope..."

  if [[ "$MODE" == "deployed" ]]; then
    # Data should already be in /data/ldn from the dissolve step
    backend_exec -e "LDN_DATA_DIR=/data/ldn" \
      -- bundle exec rails runner db/data/ldn/seed.rb
  else
    backend_exec -e "LDN_DATA_DIR=/data/ldn" -v "${LDN_DATA_DIR}:/data/ldn:ro" \
      -- bundle exec rails runner db/data/ldn/seed.rb
  fi

  ok "LDN scope seeded"
}

# ── Deployed-mode helper: copy LDN GPKGs + CSVs into container ──

copy_ldn_data_to_container() {
  docker exec "$BACKEND_CONTAINER" mkdir -p /data/ldn

  # Copy all LDN GPKG files
  for mode_name in "${!MODE_S3_FOLDERS[@]}"; do
    local gpkg="TrendsEarth_LDN_2000-2023_${mode_name}_country_ecoregion_land_types.gpkg"
    if [[ -f "${LDN_DATA_DIR}/${gpkg}" ]]; then
      info "  Copying $gpkg into container..."
      docker cp "${LDN_DATA_DIR}/${gpkg}" "${BACKEND_CONTAINER}:/data/ldn/${gpkg}"
    else
      warn "  $gpkg not found in ${LDN_DATA_DIR} — skipping"
    fi
  done

  # Copy lookup CSVs (used by dissolve_geometries for realm/country enrichment)
  for csv in ecoregion_key.csv admin0_key.csv; do
    if [[ -f "${LDN_DATA_DIR}/${csv}" ]]; then
      info "  Copying $csv into container..."
      docker cp "${LDN_DATA_DIR}/${csv}" "${BACKEND_CONTAINER}:/data/ldn/${csv}"
    elif [[ -f "${REPO_ROOT}/${csv}" ]]; then
      info "  Copying $csv into container (from repo root)..."
      docker cp "${REPO_ROOT}/${csv}" "${BACKEND_CONTAINER}:/data/ldn/${csv}"
    fi
  done
}

# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║       LDN Scope Data Setup                          ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo ""
  info "S3 bucket:        s3://${S3_BUCKET}/${S3_PREFIX}/"
  info "LDN data dir:     $LDN_DATA_DIR"
  info "Boundaries dir:   $GEOBOUNDARIES_DIR"
  echo ""

  check_aws_cli
  check_docker
  detect_mode

  if [[ "$SKIP_DOWNLOAD" == "false" ]]; then
    echo ""
    echo "── Step 1/5: Download geoBoundaries ──"
    download_boundaries

    echo ""
    echo "── Step 2/5: Download LDN datasets ──"
    download_ldn_datasets
  else
    info "Skipping downloads (--skip-download)"
  fi

  if [[ "$SKIP_BOUNDARIES" == "false" ]]; then
    echo ""
    echo "── Step 3/5: Import boundaries ──"
    import_boundaries
  else
    info "Skipping boundary import (--skip-boundaries)"
  fi

  echo ""
  echo "── Step 4/5: Dissolve LDN geometries ──"
  dissolve_ldn_geometries

  echo ""
  echo "── Step 5/5: Seed LDN site scope ──"
  seed_ldn_scope

  echo ""
  ok "All done! The LDN scope is now available."
  info "Access it at: http://localhost:3000 (subdomain: ldn)"
}

main
