#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -d "$REPO_ROOT/boundaries" ]]; then
  DEFAULT_GEOBOUNDARIES_DIR="$REPO_ROOT/boundaries"
else
  DEFAULT_GEOBOUNDARIES_DIR="/tmp/geoboundaries"
fi

GEOBOUNDARIES_DIR="${GEOBOUNDARIES_DIR:-$DEFAULT_GEOBOUNDARIES_DIR}"
FORCE_IMPORT=false

MODE=""
STACK_NAME=""
BACKEND_CONTAINER=""

readonly DATA_DIR="/data/geoboundaries"
readonly GPKG_FILES=(
  "geoBoundariesCGAZ_ADM0.gpkg"
  "geoBoundariesCGAZ_ADM1.gpkg"
  "geoBoundariesCGAZ_ADM2.gpkg"
)

info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [--force]

Imports geoBoundaries admin layers into the admin_boundaries table.

Options:
  --force           Skip the rake task confirmation prompt when data exists
  -h, --help        Show this help

Environment:
  GEOBOUNDARIES_DIR Local directory containing:
                    - geoBoundariesCGAZ_ADM0.gpkg
                    - geoBoundariesCGAZ_ADM1.gpkg
                    - geoBoundariesCGAZ_ADM2.gpkg
                    Default: $DEFAULT_GEOBOUNDARIES_DIR

Behavior:
  - On deployed staging/production hosts, copies the GPKGs into the running
    backend container and runs rake boundaries:import there.
  - In local dev, mounts or copies the same files into the backend container
    depending on whether the backend is already running.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE_IMPORT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

check_docker() {
  if ! command -v docker &>/dev/null; then
    error "Docker is not installed."
  fi
  ok "Docker available"
}

detect_mode() {
  local env=""

  if [[ -f "$REPO_ROOT/.env.staging" ]]; then
    env="staging"
  elif [[ -f "$REPO_ROOT/.env.production" ]]; then
    env="production"
  fi

  if [[ -z "$env" ]]; then
    if docker service ls 2>/dev/null | grep -q "resilienceatlas-staging_backend"; then
      env="staging"
    elif docker service ls 2>/dev/null | grep -q "resilienceatlas-production_backend"; then
      env="production"
    fi
  fi

  if [[ -z "$env" ]]; then
    case "$REPO_ROOT" in
      */resilienceatlas-staging*)
        env="staging"
        ;;
      */resilienceatlas-production*)
        env="production"
        ;;
    esac
  fi

  if [[ -n "$env" ]]; then
    MODE="deployed"
    STACK_NAME="resilienceatlas-${env}"
    info "Detected deployed environment: ${env}"

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

backend_exec() {
  local env_args=()
  local vol_args=()
  local cmd_args=()
  local parsing_opts=true

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
    docker exec \
      ${env_args[@]+"${env_args[@]}"} \
      "$BACKEND_CONTAINER" "${cmd_args[@]}"
  else
    local running
    running=$(docker compose -f "$REPO_ROOT/docker-compose.dev.yml" ps -q backend 2>/dev/null || true)
    if [[ -n "$running" ]]; then
      docker compose -f "$REPO_ROOT/docker-compose.dev.yml" exec \
        ${env_args[@]+"${env_args[@]}"} \
        backend "${cmd_args[@]}"
    else
      docker compose -f "$REPO_ROOT/docker-compose.dev.yml" run --rm \
        ${env_args[@]+"${env_args[@]}"} \
        ${vol_args[@]+"${vol_args[@]}"} \
        backend "${cmd_args[@]}"
    fi
  fi
}

check_boundary_files() {
  [[ -d "$GEOBOUNDARIES_DIR" ]] || error "GEOBOUNDARIES_DIR does not exist: $GEOBOUNDARIES_DIR"

  local missing=()
  local file
  for file in "${GPKG_FILES[@]}"; do
    if [[ ! -f "$GEOBOUNDARIES_DIR/$file" ]]; then
      missing+=("$file")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing GeoPackage files in $GEOBOUNDARIES_DIR: ${missing[*]}"
  fi

  ok "Boundary GeoPackages found in $GEOBOUNDARIES_DIR"
}

copy_boundaries_into_container() {
  local container_id="$1"
  local file

  docker exec "$container_id" mkdir -p "$DATA_DIR"

  for file in "${GPKG_FILES[@]}"; do
    info "Copying $file into container"
    docker cp "$GEOBOUNDARIES_DIR/$file" "$container_id:$DATA_DIR/$file"
  done
}

run_import() {
  local env_args=()
  if [[ "$FORCE_IMPORT" == true ]]; then
    env_args+=("-e" "FORCE=1")
  fi

  info "Importing geoBoundaries into database..."

  if [[ "$MODE" == "deployed" ]]; then
    copy_boundaries_into_container "$BACKEND_CONTAINER"
    backend_exec ${env_args[@]+"${env_args[@]}"} -- bundle exec rake boundaries:import
  else
    local running
    running=$(docker compose -f "$REPO_ROOT/docker-compose.dev.yml" ps -q backend 2>/dev/null || true)
    if [[ -n "$running" ]]; then
      info "Backend already running — copying files into container"
      copy_boundaries_into_container "$running"
      backend_exec ${env_args[@]+"${env_args[@]}"} -- bundle exec rake boundaries:import
    else
      info "Starting database (if needed)..."
      docker compose -f "$REPO_ROOT/docker-compose.dev.yml" up -d db
      backend_exec \
        ${env_args[@]+"${env_args[@]}"} \
        -v "$GEOBOUNDARIES_DIR:$DATA_DIR:ro" \
        -- bundle exec rake boundaries:import
    fi
  fi

  ok "Boundaries imported"
  backend_exec -- bundle exec rake boundaries:status
}

main() {
  check_docker
  detect_mode
  check_boundary_files

  info "GeoBoundaries dir: $GEOBOUNDARIES_DIR"
  run_import
}

main "$@"