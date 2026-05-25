#!/usr/bin/env python3
"""
Generate list of TIFF keys that need to be regenerated with OVERVIEW_RESAMPLING=NEAREST.

This script queries the database to find all categorical layers, extracts the
table names from their layer_config, and generates the corresponding S3 keys
for the source TIFF files.

Usage:
    python generate_categorical_tiff_list.py                    # Print comma-separated list
    python generate_categorical_tiff_list.py --format=lines     # Print one per line
    python generate_categorical_tiff_list.py --format=env       # Print as TIFF_KEYS=... for export
    python generate_categorical_tiff_list.py --output=list.txt  # Write to file
"""

import argparse
import json
import os
import sys
from typing import List, Set

try:
    import psycopg2
except ImportError:
    print("ERROR: psycopg2 is required. Install with: pip install psycopg2-binary")
    sys.exit(1)


def get_db_connection():
    """Get database connection from environment variables."""
    db_host = os.environ.get("DB_HOST", "localhost")
    db_port = os.environ.get("DB_PORT", "5432")
    db_name = os.environ.get("DB_NAME", "resilienceatlas_development")
    db_user = os.environ.get("DB_USER", "postgres")
    db_password = os.environ.get("DB_PASSWORD", "")
    
    try:
        conn = psycopg2.connect(
            host=db_host,
            port=db_port,
            database=db_name,
            user=db_user,
            password=db_password
        )
        return conn
    except psycopg2.Error as e:
        print(f"ERROR: Failed to connect to database: {e}")
        print("\nSet these environment variables:")
        print("  DB_HOST (default: localhost)")
        print("  DB_PORT (default: 5432)")
        print("  DB_NAME (default: resilienceatlas_development)")
        print("  DB_USER (default: postgres)")
        print("  DB_PASSWORD")
        sys.exit(1)


def extract_table_names_from_layer(layer_config: dict) -> Set[str]:
    """
    Extract table names from a layer's config.
    
    Looks in:
    - cartodb_migration.tables (keys)
    - cartodb_migration.raster_tables (array)
    - Parses source SQL if available
    """
    tables = set()
    
    migration = layer_config.get("cartodb_migration", {})
    
    # From tables object (keys are table names)
    if "tables" in migration and isinstance(migration["tables"], dict):
        tables.update(migration["tables"].keys())
    
    # From raster_tables array
    if "raster_tables" in migration and isinstance(migration["raster_tables"], list):
        tables.update(migration["raster_tables"])
    
    # From source SQL (extract table names from FROM clauses)
    # This is a simple extraction - may miss complex queries
    source_sql = migration.get("source_sql", "")
    if source_sql:
        import re
        # Match table names after FROM or JOIN
        pattern = r'\b(?:FROM|JOIN)\s+([a-z_][a-z0-9_]*)\b'
        matches = re.findall(pattern, source_sql, re.IGNORECASE)
        tables.update(matches)
    
    return tables


def get_categorical_layer_tables() -> Set[str]:
    """Query database for all categorical layers and extract their table names."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Query for categorical COG layers
    query = """
        SELECT 
            id,
            slug,
            layer_config
        FROM layers 
        WHERE layer_provider = 'cog' 
          AND analysis_type = 'categorical'
          AND layer_config IS NOT NULL
        ORDER BY id;
    """
    
    try:
        cursor.execute(query)
        rows = cursor.fetchall()
        
        all_tables = set()
        layer_count = 0
        
        print(f"Found {len(rows)} categorical layers", file=sys.stderr)
        
        for layer_id, slug, layer_config_json in rows:
            try:
                layer_config = json.loads(layer_config_json)
                tables = extract_table_names_from_layer(layer_config)
                
                if tables:
                    print(f"  Layer #{layer_id} ({slug}): {len(tables)} table(s)", file=sys.stderr)
                    for table in sorted(tables):
                        print(f"    - {table}", file=sys.stderr)
                    all_tables.update(tables)
                    layer_count += 1
                else:
                    print(f"  Layer #{layer_id} ({slug}): No tables found", file=sys.stderr)
                    
            except json.JSONDecodeError:
                print(f"  WARNING: Layer #{layer_id} has invalid JSON config", file=sys.stderr)
                continue
        
        print(f"\nTotal unique tables: {len(all_tables)}", file=sys.stderr)
        print(f"From {layer_count} categorical layers\n", file=sys.stderr)
        
        return all_tables
        
    finally:
        cursor.close()
        conn.close()


def table_to_s3_key(table_name: str, source_prefix: str = "cartodb_exports/rasters/") -> str:
    """
    Convert a table name to the expected S3 key for the source TIFF.
    
    The table name may have schema prefixes like 'public_' or 'cdb_importer_'
    which we preserve in the S3 key since that's how the files were exported.
    """
    return f"{source_prefix}{table_name}.tif"


def main():
    parser = argparse.ArgumentParser(
        description="Generate list of categorical TIFF keys for COG regeneration"
    )
    parser.add_argument(
        "--format",
        choices=["comma", "lines", "env"],
        default="comma",
        help="Output format: comma-separated, one per line, or as TIFF_KEYS=..."
    )
    parser.add_argument(
        "--output",
        help="Write to file instead of stdout"
    )
    parser.add_argument(
        "--source-prefix",
        default="cartodb_exports/rasters/",
        help="S3 prefix for source TIFFs (default: cartodb_exports/rasters/)"
    )
    parser.add_argument(
        "--filter",
        help="Only include tables matching this substring (case-insensitive)"
    )
    
    args = parser.parse_args()
    
    # Get table names from database
    tables = get_categorical_layer_tables()
    
    if not tables:
        print("ERROR: No categorical tables found", file=sys.stderr)
        sys.exit(1)
    
    # Apply filter if specified
    if args.filter:
        filter_lower = args.filter.lower()
        tables = {t for t in tables if filter_lower in t.lower()}
        print(f"After filter '{args.filter}': {len(tables)} table(s)", file=sys.stderr)
    
    # Convert to S3 keys
    keys = sorted([table_to_s3_key(t, args.source_prefix) for t in tables])
    
    # Format output
    if args.format == "comma":
        output = ",".join(keys)
    elif args.format == "lines":
        output = "\n".join(keys)
    elif args.format == "env":
        output = f'TIFF_KEYS="{",".join(keys)}"'
    
    # Write to file or stdout
    if args.output:
        with open(args.output, "w") as f:
            f.write(output)
            if args.format == "lines":
                f.write("\n")
        print(f"Wrote {len(keys)} keys to {args.output}", file=sys.stderr)
    else:
        print(output)
    
    # Print summary to stderr
    if not args.output:
        print(f"\n# Total: {len(keys)} TIFF files to regenerate", file=sys.stderr)
        print(f"# Use with: TIFF_KEYS='...' python batch_handler.py", file=sys.stderr)


if __name__ == "__main__":
    main()
