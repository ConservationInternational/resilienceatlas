#!/usr/bin/env python3
"""
Regenerate categorical COGs with NEAREST resampling.

This is a convenience script that:
1. Queries the database for categorical layers
2. Generates the list of TIFF keys
3. Runs the batch conversion with OVERVIEW_RESAMPLING=NEAREST

Usage:
    # Dry run (preview what would be done)
    python regenerate_categorical_cogs.py --dry-run
    
    # Actually regenerate
    python regenerate_categorical_cogs.py
    
    # Regenerate specific layers only
    python regenerate_categorical_cogs.py --filter=land_cover
    
    # Test with just one file
    python regenerate_categorical_cogs.py --limit=1
"""

import argparse
import os
import subprocess
import sys

# Add the script directory to path so we can import from generate_categorical_tiff_list
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)

try:
    from generate_categorical_tiff_list import get_categorical_layer_tables, table_to_s3_key
except ImportError as e:
    print(f"ERROR: Failed to import helper functions: {e}")
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Regenerate categorical COGs with NEAREST resampling"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview what would be done without actually converting"
    )
    parser.add_argument(
        "--filter",
        help="Only process tables matching this substring"
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Limit to first N files (for testing)"
    )
    parser.add_argument(
        "--source-prefix",
        default="cartodb_exports/rasters/",
        help="S3 prefix for source TIFFs"
    )
    
    args = parser.parse_args()
    
    # Required environment variables
    s3_bucket = os.environ.get("S3_BUCKET")
    if not s3_bucket:
        print("ERROR: S3_BUCKET environment variable not set")
        print("\nUsage:")
        print("  export S3_BUCKET=resilienceatlas")
        print("  export AWS_PROFILE=resilienceatlas  # if needed")
        print("  python regenerate_categorical_cogs.py")
        sys.exit(1)
    
    print("=" * 80)
    print("Categorical COG Regeneration")
    print("=" * 80)
    print(f"S3 Bucket: {s3_bucket}")
    print(f"Source Prefix: {args.source_prefix}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    if args.filter:
        print(f"Filter: {args.filter}")
    if args.limit:
        print(f"Limit: {args.limit} file(s)")
    print()
    
    # Get categorical tables from database
    print("Querying database for categorical layers...")
    tables = get_categorical_layer_tables()
    
    if not tables:
        print("ERROR: No categorical tables found")
        sys.exit(1)
    
    # Apply filter
    if args.filter:
        filter_lower = args.filter.lower()
        tables = {t for t in tables if filter_lower in t.lower()}
        print(f"After filter: {len(tables)} table(s)")
    
    # Convert to S3 keys
    keys = sorted([table_to_s3_key(t, args.source_prefix) for t in tables])
    
    # Apply limit
    if args.limit:
        keys = keys[:args.limit]
        print(f"Limited to first {len(keys)} file(s)")
    
    print(f"\nFiles to regenerate ({len(keys)}):")
    for i, key in enumerate(keys, 1):
        print(f"  {i}. {key}")
    
    if args.dry_run:
        print("\n" + "=" * 80)
        print("DRY RUN - would execute:")
        print("=" * 80)
        print(f"S3_BUCKET={s3_bucket}")
        print(f"OVERVIEW_RESAMPLING=NEAREST")
        print(f"OVERWRITE=true")
        print(f'TIFF_KEYS="{",".join(keys)}"')
        print("python batch_container/batch_handler.py")
        print("\nTo run for real, remove --dry-run flag")
        return
    
    # Confirm before proceeding
    print("\n" + "=" * 80)
    print("WARNING: This will OVERWRITE existing COG files!")
    print("=" * 80)
    response = input(f"\nProceed with regenerating {len(keys)} COG file(s)? [y/N]: ")
    
    if response.lower() not in ['y', 'yes']:
        print("Aborted.")
        sys.exit(0)
    
    # Set environment variables for batch handler
    env = os.environ.copy()
    env["S3_BUCKET"] = s3_bucket
    env["OVERVIEW_RESAMPLING"] = "NEAREST"
    env["OVERWRITE"] = "true"
    env["TIFF_KEYS"] = ",".join(keys)
    
    # Path to batch handler
    batch_handler = os.path.join(script_dir, "batch_container", "batch_handler.py")
    
    if not os.path.exists(batch_handler):
        print(f"ERROR: batch_handler.py not found at {batch_handler}")
        sys.exit(1)
    
    print("\n" + "=" * 80)
    print("Running batch conversion...")
    print("=" * 80)
    
    # Run batch handler
    try:
        result = subprocess.run(
            [sys.executable, batch_handler],
            env=env,
            check=False
        )
        
        if result.returncode != 0:
            print(f"\nERROR: Batch conversion failed with exit code {result.returncode}")
            sys.exit(result.returncode)
        
        print("\n" + "=" * 80)
        print("SUCCESS: Categorical COGs regenerated!")
        print("=" * 80)
        print(f"Regenerated {len(keys)} file(s) with OVERVIEW_RESAMPLING=NEAREST")
        print("\nNext steps:")
        print("  1. Clear browser cache")
        print("  2. Reload staging site")
        print("  3. Check land cover layers at zoom 3-8")
        print("  4. Verify clean boundaries (no noise)")
        
    except KeyboardInterrupt:
        print("\n\nAborted by user.")
        sys.exit(1)


if __name__ == "__main__":
    main()
