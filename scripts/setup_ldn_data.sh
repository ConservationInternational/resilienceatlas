#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# setup_ldn_data.sh
#
# Downloads LDN (Land Degradation Neutrality) datasets and
# geoBoundaries GeoPackage files from the trends.earth-private S3
# bucket, then runs the existing rake tasks to import boundaries
# and dissolve LDN geometries, and finally seeds the LDN scope.
#
# Prerequisites:
#   - AWS CLI configured with access to the trends.earth-private bucket
#   - Docker + docker compose available
#   - The ResilienceAtlas dev environment (docker-compose.dev.yml)
#
# Usage:
#   ./scripts/setup_ldn_data.sh [--profile <aws-profile>] [--skip-download] [--skip-boundaries]
#
# Environment variables:
#   AWS_PROFILE          — AWS CLI profile to use (or pass --profile)
#   LDN_DATA_DIR         — Local directory for LDN data (default: repo root)
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
      echo "  LDN_DATA_DIR       Local dir for LDN data (default: repo root)"
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
  if ! docker compose version &>/dev/null; then
    error "docker compose is not available."
  fi
  ok "Docker compose available"
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

  for mode_name in "${!MODE_S3_FOLDERS[@]}"; do
    local s3_folder="${MODE_S3_FOLDERS[$mode_name]}"
    local s3_base="s3://${S3_BUCKET}/${S3_PREFIX}/${s3_folder}"

    info "  Mode: $mode_name (s3 folder: $s3_folder)"

    # Only the country_ecoregion GPKG is needed (dissolve_geometries + seed)
    local gpkg="TrendsEarth_LDN_2000-2023_${mode_name}_country_ecoregion_land_types.gpkg"
    download_file "$s3_base/${gpkg}" "${LDN_DATA_DIR}/${gpkg}"
  done

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

  # Ensure dev environment is running
  info "  Starting database (if not already running)..."
  docker compose -f "$REPO_ROOT/docker-compose.dev.yml" up -d db
  info "  Waiting for database to be ready..."
  sleep 5

  docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
    -v "${GEOBOUNDARIES_DIR}:/data/geoboundaries:ro" \
    backend bundle exec rake boundaries:import

  ok "Boundaries imported"

  # Show status
  docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
    backend bundle exec rake boundaries:status
}

# ──────────────────────────────────────────────────────────────
# Step 4: Dissolve LDN geometries
# ──────────────────────────────────────────────────────────────

dissolve_ldn_geometries() {
  info "Dissolving LDN geometries..."

  docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
    -e "LDN_DATA_DIR=/data/ldn" \
    -v "${LDN_DATA_DIR}:/data/ldn:ro" \
    backend bundle exec rake ldn:dissolve_geometries

  ok "LDN geometries dissolved"

  # Show status
  docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
    backend bundle exec rake ldn:dissolve_status
}

# ──────────────────────────────────────────────────────────────
# Step 5: Run LDN seed
# ──────────────────────────────────────────────────────────────

seed_ldn_scope() {
  info "Seeding LDN site scope..."

  docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
    -e "LDN_DATA_DIR=/data/ldn" \
    -v "${LDN_DATA_DIR}:/data/ldn:ro" \
    backend bundle exec rails runner db/data/ldn/seed.rb

  ok "LDN scope seeded"
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
