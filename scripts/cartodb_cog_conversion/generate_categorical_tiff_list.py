#!/usr/bin/env python3
"""
Generate list of TIFF keys that need to be regenerated with OVERVIEW_RESAMPLING=NEAREST.

This script queries the database to find all categorical layers by:
1. Checking analysis_type='categorical' field
2. Analyzing colormap characteristics (discrete stops, exact flags, integer values)

Usage:
    python generate_categorical_tiff_list.py                    # Print comma-separated list
    python generate_categorical_tiff_list.py --format=lines     # Print one per line
    python generate_categorical_tiff_list.py --format=env       # Print as TIFF_KEYS=... for export
    python generate_categorical_tiff_list.py --output=list.txt  # Write to file
    python generate_categorical_tiff_list.py --no-analysis-type # Only use colormap analysis
    python generate_categorical_tiff_list.py --min-confidence=0.7  # Colormap detection threshold
"""

import argparse
import json
import os
import sys
from typing import List, Set, Dict, Tuple

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


def is_categorical_colormap(layer_config: dict, min_confidence: float = 0.6) -> Tuple[bool, float, str]:
    """
    Analyze a layer's colormap to determine if it represents categorical data.

    The stored colormap format (from build_interval_colormap / build_fine_interval_colormap)
    is always a list of [[lower, upper], [r, g, b, a]] interval pairs.
    build_gradient_colormap produces a dict {"key": [r,g,b,a]} which is definitively
    continuous and short-circuits here.

    Signals used (in descending reliability):
    1. Narrow intervals  [v, v+0.001] — exact-mode markers written by the rake task
       for CartoDB CSS `stop(value, color, exact)`.  Most reliable indicator.
    2. Sequential integers (consecutive or regular small step ≤ 10) — class enumeration.
    3. Integer lower-bound values — class codes are integers; BUT only treated as strong
       evidence when the value range is small (≤ 500), because continuous layers can
       also use rounded integers for threshold stops (e.g. 0, 500, 1000, 5000 mm rain).
    4. Stop count — weak supporting evidence only; never used as sole indicator.
       Many stops lean against categorical.

    Returns:
        (is_categorical, confidence_score, reason_string)
    """
    body = layer_config.get("body", {})
    colormap = body.get("colormap")

    if not colormap:
        return (False, 0.0, "No colormap")

    if isinstance(colormap, str):
        try:
            colormap = json.loads(colormap)
        except Exception:
            return (False, 0.0, "Invalid colormap JSON")

    # Gradient colormaps are a dict {"key": [r,g,b,a]} — definitively continuous.
    if isinstance(colormap, dict):
        return (False, 0.0, "Gradient colormap (continuous)")

    if not isinstance(colormap, list) or len(colormap) == 0:
        return (False, 0.0, "Empty or invalid colormap")

    scores = []
    reasons = []
    num_stops = len(colormap)

    # --- Parse lower-bound values and detect narrow (exact-mode) intervals ---
    # Interval format: [[lower, upper], [r, g, b, a]]
    # Narrow = upper - lower <= 0.001, produced by exact-mode stops in the rake task.
    values = []
    narrow_count = 0

    for stop in colormap:
        if not isinstance(stop, list) or len(stop) < 2:
            continue
        value_part = stop[0]
        if isinstance(value_part, list) and len(value_part) == 2:
            try:
                lower = float(value_part[0])
                upper = float(value_part[1])
                values.append(lower)
                if (upper - lower) <= 0.01:
                    narrow_count += 1
            except (ValueError, TypeError):
                pass
        else:
            try:
                values.append(float(value_part))
            except (ValueError, TypeError):
                pass

    if not values:
        return (False, 0.0, "No parseable stop values")

    # --- Signal 1: Narrow intervals (exact-mode markers) ---
    # These are written explicitly for categorical stops by the rake task.
    if narrow_count > 0:
        narrow_ratio = narrow_count / num_stops
        if narrow_ratio >= 0.8:
            scores.append(1.0)
            reasons.append(f"Exact-mode stops ({narrow_count}/{num_stops})")
        elif narrow_ratio >= 0.3:
            scores.append(0.7)
            reasons.append(f"Some exact-mode stops ({narrow_count}/{num_stops})")
        else:
            scores.append(0.4)
            reasons.append(f"Few exact-mode stops ({narrow_count}/{num_stops})")

    # --- Signal 2: Sequential integers ---
    # Consecutive integers (0,1,2,3...) or a regular small step (e.g. 10,20,30)
    # strongly suggest class enumeration, regardless of starting value.
    integer_values = [v for v in values if v == int(v)]
    integer_count = len(integer_values)
    integer_ratio = integer_count / len(values) if values else 0.0

    if len(integer_values) >= 3:
        sorted_int = sorted(set(int(v) for v in integer_values))
        diffs = [sorted_int[i + 1] - sorted_int[i] for i in range(len(sorted_int) - 1)]
        if all(d == 1 for d in diffs):
            scores.append(1.0)
            reasons.append(f"Sequential integer classes ({sorted_int[0]}–{sorted_int[-1]})")
        elif len(set(diffs)) == 1 and 1 < diffs[0] <= 10:
            # Regular small increment — e.g. steps of 2, 5, or 10
            scores.append(0.7)
            reasons.append(f"Regular class increments (step={diffs[0]})")

    # --- Signal 3: Integer values ---
    # Class codes are integers, but continuous layers can also use rounded integer
    # thresholds.  Only treat as strong evidence when value range is small (≤ 500),
    # because large-range integers (e.g. 0, 500, 1000, 5000) indicate thresholds.
    if integer_ratio >= 0.8:
        value_range = max(values) - min(values)
        if value_range <= 500:
            scores.append(1.0)
            reasons.append(f"Integer values, small range ({integer_count}/{len(values)}, range={value_range:.0f})")
        else:
            # Large-range integers: mild evidence only
            scores.append(0.4)
            reasons.append(f"Integer values, large range ({integer_count}/{len(values)}, range={value_range:.0f})")
    elif integer_ratio >= 0.5:
        scores.append(0.5)
        reasons.append(f"Mostly integer values ({integer_count}/{len(values)})")
    # < 50% integers: not informative — don't add to scores

    # --- Signal 4: Stop count (supporting evidence only) ---
    # Never decisive on its own; just nudges borderline cases.
    if num_stops <= 8:
        scores.append(0.5)
        reasons.append(f"Very few stops ({num_stops})")
    elif num_stops <= 20:
        scores.append(0.3)
        reasons.append(f"Few stops ({num_stops})")
    elif num_stops > 50:
        scores.append(0.0)  # Many stops reduce overall average
        reasons.append(f"Many stops ({num_stops})")
    # 21–50 stops: neutral, don't add

    confidence = sum(scores) / len(scores) if scores else 0.0
    is_categorical = confidence >= min_confidence
    reason = "; ".join(reasons[:4])

    return (is_categorical, confidence, reason)


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


def get_categorical_layer_tables(use_analysis_type: bool = True, min_confidence: float = 0.6) -> Set[str]:
    """
    Query database for all categorical layers and extract their table names.
    
    Args:
        use_analysis_type: If True, include layers with analysis_type='categorical'
        min_confidence: Minimum confidence score for colormap-based detection (0.0-1.0)
    
    Returns:
        Set of table names
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Query for all COG layers
    query = """
        SELECT 
            id,
            slug,
            analysis_type,
            layer_config
        FROM layers 
        WHERE layer_provider = 'cog' 
          AND layer_config IS NOT NULL
        ORDER BY id;
    """
    
    try:
        cursor.execute(query)
        rows = cursor.fetchall()
        
        all_tables = set()
        layer_count = 0
        
        print(f"Analyzing {len(rows)} COG layers...", file=sys.stderr)
        print("", file=sys.stderr)
        
        categorical_by_type = 0
        categorical_by_colormap = 0
        
        for layer_id, slug, analysis_type, layer_config_json in rows:
            try:
                layer_config = json.loads(layer_config_json)
                
                is_categorical = False
                method = ""
                
                # Method 1: Check analysis_type field
                if use_analysis_type and analysis_type == 'categorical':
                    is_categorical = True
                    method = "analysis_type"
                    categorical_by_type += 1
                
                # Method 2: Analyze colormap
                if not is_categorical:
                    is_cat_colormap, confidence, reason = is_categorical_colormap(
                        layer_config, 
                        min_confidence
                    )
                    if is_cat_colormap:
                        is_categorical = True
                        method = f"colormap (confidence={confidence:.2f}: {reason})"
                        categorical_by_colormap += 1
                
                if is_categorical:
                    tables = extract_table_names_from_layer(layer_config)
                    
                    if tables:
                        print(f"  ✓ Layer #{layer_id} ({slug}): {len(tables)} table(s) [{method}]", file=sys.stderr)
                        for table in sorted(tables):
                            print(f"      - {table}", file=sys.stderr)
                        all_tables.update(tables)
                        layer_count += 1
                    else:
                        print(f"  ⚠ Layer #{layer_id} ({slug}): Categorical but no tables found [{method}]", file=sys.stderr)
                    
            except json.JSONDecodeError:
                print(f"  ✗ Layer #{layer_id}: Invalid JSON config", file=sys.stderr)
                continue
        
        print("", file=sys.stderr)
        print(f"Summary:", file=sys.stderr)
        print(f"  Categorical by analysis_type: {categorical_by_type}", file=sys.stderr)
        print(f"  Categorical by colormap:      {categorical_by_colormap}", file=sys.stderr)
        print(f"  Total categorical layers:     {layer_count}", file=sys.stderr)
        print(f"  Unique tables:                {len(all_tables)}", file=sys.stderr)
        print("", file=sys.stderr)
        
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
        description="Generate list of categorical TIFF keys for COG regeneration",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Detection Methods:
  1. analysis_type field: Layers explicitly marked as 'categorical'
  2. Colormap analysis: Detects categorical colormaps by characteristics:
     - Few stops (< 20)
     - Integer values
     - Exact flags
     - Large gaps between values
     - Sequential or round number patterns

Examples:
  # Use both detection methods (default)
  python generate_categorical_tiff_list.py --output=categorical.txt
  
  # Only use colormap analysis (ignore analysis_type field)
  python generate_categorical_tiff_list.py --no-analysis-type --output=colormap.txt
  
  # Stricter colormap detection
  python generate_categorical_tiff_list.py --min-confidence=0.8
  
  # More lenient colormap detection
  python generate_categorical_tiff_list.py --min-confidence=0.4
        """
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
    parser.add_argument(
        "--no-analysis-type",
        action="store_true",
        help="Don't use analysis_type field, only colormap analysis"
    )
    parser.add_argument(
        "--min-confidence",
        type=float,
        default=0.6,
        help="Minimum confidence score for colormap detection (0.0-1.0, default: 0.6)"
    )
    
    args = parser.parse_args()
    
    # Get table names from database
    use_analysis_type = not args.no_analysis_type
    tables = get_categorical_layer_tables(
        use_analysis_type=use_analysis_type,
        min_confidence=args.min_confidence
    )
    
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
