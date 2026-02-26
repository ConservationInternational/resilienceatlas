#!/usr/bin/env bash
# =============================================================================
# import_geoboundaries.sh
#
# Imports geoBoundaries CGAZ GeoPackage files (ADM0, ADM1, ADM2) into the
# admin_boundaries table in the Resilience Atlas PostGIS database.
#
# Prerequisites:
#   - ogr2ogr (part of GDAL) must be installed
#   - The database must already have the admin_boundaries table
#     (run: rails db:migrate)
#   - The three .gpkg files must exist at the paths specified below
#
# Usage:
#   # With environment variables:
#   DATABASE_URL=postgres://user:pass@host:port/dbname ./scripts/import_geoboundaries.sh
#
#   # Or with individual variables:
#   DATABASE_HOST=localhost DATABASE_PORT=5432 DATABASE_USER=postgres \
#     DATABASE_PASSWORD=postgres DATABASE_NAME=cigrp \
#     ./scripts/import_geoboundaries.sh
#
#   # Inside Docker:
#   docker compose -f docker-compose.dev.yml exec backend \
#     bash scripts/import_geoboundaries.sh
#
# The script will:
#   1. Truncate the admin_boundaries table
#   2. Import ADM0 (countries) from geoBoundariesCGAZ_ADM0.gpkg
#   3. Import ADM1 (provinces/states) from geoBoundariesCGAZ_ADM1.gpkg
#   4. Import ADM2 (districts) from geoBoundariesCGAZ_ADM2.gpkg
#   5. Verify the import counts
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Database connection
# ---------------------------------------------------------------------------
if [ -n "${DATABASE_URL:-}" ]; then
  PG_CONN="$DATABASE_URL"
else
  DB_HOST="${DATABASE_HOST:-localhost}"
  DB_PORT="${DATABASE_PORT:-5432}"
  DB_USER="${DATABASE_USER:-postgres}"
  DB_PASS="${DATABASE_PASSWORD:-postgres}"
  DB_NAME="${DATABASE_NAME:-cigrp}"
  PG_CONN="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi

# ---------------------------------------------------------------------------
# File paths — relative to the repo root
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ADM0_GPKG="${REPO_ROOT}/geoBoundariesCGAZ_ADM0.gpkg"
ADM1_GPKG="${REPO_ROOT}/geoBoundariesCGAZ_ADM1.gpkg"
ADM2_GPKG="${REPO_ROOT}/geoBoundariesCGAZ_ADM2.gpkg"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
echo "=== geoBoundaries → admin_boundaries importer ==="
echo ""

if ! command -v ogr2ogr &>/dev/null; then
  echo "❌  ogr2ogr not found. Install GDAL first:"
  echo "    apt-get install gdal-bin   (Debian/Ubuntu)"
  echo "    brew install gdal          (macOS)"
  exit 1
fi

if ! command -v psql &>/dev/null; then
  echo "❌  psql not found. Install postgresql-client first."
  exit 1
fi

for f in "$ADM0_GPKG" "$ADM1_GPKG" "$ADM2_GPKG"; do
  if [ ! -f "$f" ]; then
    echo "❌  Missing file: $f"
    echo "   Download CGAZ GeoPackages from https://www.geoboundaries.org/globalDownloads.html"
    exit 1
  fi
done

echo "📦  ADM0: $ADM0_GPKG"
echo "📦  ADM1: $ADM1_GPKG"
echo "📦  ADM2: $ADM2_GPKG"
echo "🗄️  Database: $PG_CONN"
echo ""

# ---------------------------------------------------------------------------
# Determine the layer names inside each GeoPackage
# ---------------------------------------------------------------------------
get_layer_name() {
  ogrinfo -q "$1" | head -1 | sed 's/^[0-9]*: //' | sed 's/ (.*//'
}

ADM0_LAYER=$(get_layer_name "$ADM0_GPKG")
ADM1_LAYER=$(get_layer_name "$ADM1_GPKG")
ADM2_LAYER=$(get_layer_name "$ADM2_GPKG")

echo "   ADM0 layer: $ADM0_LAYER"
echo "   ADM1 layer: $ADM1_LAYER"
echo "   ADM2 layer: $ADM2_LAYER"
echo ""

# ---------------------------------------------------------------------------
# Truncate existing data
# ---------------------------------------------------------------------------
echo "🗑️  Truncating admin_boundaries table..."
psql "$PG_CONN" -c "TRUNCATE TABLE admin_boundaries RESTART IDENTITY;"

# ---------------------------------------------------------------------------
# Import helper
# Converts the GeoPackage to the admin_boundaries table via a temp table,
# mapping geoBoundaries column names to our schema.
# ---------------------------------------------------------------------------
import_level() {
  local LEVEL=$1
  local GPKG_FILE=$2
  local LAYER_NAME=$3
  local TEMP_TABLE="temp_adm${LEVEL}_import"

  echo "⬆️  Importing ADM${LEVEL} from $(basename "$GPKG_FILE")..."

  # Step 1: Load the raw GeoPackage into a temporary table.
  # ogr2ogr will create the table structure to match the .gpkg schema.
  ogr2ogr \
    -f "PostgreSQL" \
    "PG:${PG_CONN}" \
    "$GPKG_FILE" \
    "$LAYER_NAME" \
    -nln "$TEMP_TABLE" \
    -overwrite \
    -lco GEOMETRY_NAME=geom \
    -lco FID=ogc_fid \
    -t_srs "EPSG:4326" \
    -nlt PROMOTE_TO_MULTI \
    --config PG_USE_COPY YES \
    -progress

  # Step 2: Map columns from the temp table into admin_boundaries.
  # geoBoundaries CGAZ columns (all lowercase after ogr2ogr import):
  #   ADM0: shapegroup (ISO3), shapename, geometry
  #   ADM1: shapegroup (ISO3 parent), shapename, shapeid, geometry
  #   ADM2: shapegroup (ISO3 parent), shapename, shapeid, geometry
  case $LEVEL in
    0)
      psql "$PG_CONN" -c "
        INSERT INTO admin_boundaries (name, iso_code, admin_level, parent_iso_code, geom, created_at, updated_at)
        SELECT
          \"shapename\",
          \"shapegroup\",
          0,
          NULL,
          geom,
          NOW(),
          NOW()
        FROM ${TEMP_TABLE};
      "
      ;;
    1)
      psql "$PG_CONN" -c "
        INSERT INTO admin_boundaries (name, iso_code, admin_level, parent_iso_code, geom, created_at, updated_at)
        SELECT
          \"shapename\",
          COALESCE(\"shapeid\", \"shapegroup\" || '_' || \"shapename\"),
          1,
          \"shapegroup\",
          geom,
          NOW(),
          NOW()
        FROM ${TEMP_TABLE};
      "
      ;;
    2)
      psql "$PG_CONN" -c "
        INSERT INTO admin_boundaries (name, iso_code, admin_level, parent_iso_code, geom, created_at, updated_at)
        SELECT
          COALESCE(\"shapename\", \"shapeid\", 'Unknown'),
          COALESCE(\"shapeid\", \"shapegroup\" || '_' || COALESCE(\"shapename\", 'unknown')),
          2,
          \"shapegroup\",
          geom,
          NOW(),
          NOW()
        FROM ${TEMP_TABLE};
      "
      ;;
  esac

  # Step 3: Drop the temp table
  psql "$PG_CONN" -c "DROP TABLE IF EXISTS ${TEMP_TABLE};"

  echo "   ✅  ADM${LEVEL} import complete"
  echo ""
}

# ---------------------------------------------------------------------------
# Run imports
# ---------------------------------------------------------------------------
import_level 0 "$ADM0_GPKG" "$ADM0_LAYER"
import_level 1 "$ADM1_GPKG" "$ADM1_LAYER"
import_level 2 "$ADM2_GPKG" "$ADM2_LAYER"

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
echo "📊  Verifying import counts..."
psql "$PG_CONN" -c "
  SELECT
    admin_level,
    CASE admin_level
      WHEN 0 THEN 'Countries (ADM0)'
      WHEN 1 THEN 'Provinces/States (ADM1)'
      WHEN 2 THEN 'Districts (ADM2)'
    END AS description,
    COUNT(*) AS count
  FROM admin_boundaries
  GROUP BY admin_level
  ORDER BY admin_level;
"

TOTAL=$(psql "$PG_CONN" -t -c "SELECT COUNT(*) FROM admin_boundaries;")
echo "   Total boundaries: ${TOTAL}"
echo ""
echo "✅  geoBoundaries import complete!"
