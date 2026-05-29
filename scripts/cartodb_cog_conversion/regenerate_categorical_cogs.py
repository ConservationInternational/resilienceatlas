#!/usr/bin/env python3
"""
Regenerate categorical COGs with NEAREST resampling.

This is a convenience script that:
1. Queries the database for categorical layers
2. Generates the list of TIFF keys
3. Calls manage_cog_conversion.py regenerate to submit AWS Batch jobs

Usage:
    # Dry run (preview what would be done)
    python regenerate_categorical_cogs.py --dry-run
    
    # Actually regenerate via AWS Batch
    python regenerate_categorical_cogs.py
    
    # Regenerate specific layers only
    python regenerate_categorical_cogs.py --filter=land_cover
    
    # Test with just one file
    python regenerate_categorical_cogs.py --limit=1

Environment variables:
    S3_BUCKET: S3 bucket name (required)
    AWS_PROFILE: AWS credentials profile (optional)
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD: Database connection
"""

import argparse
import os
import subprocess
import sys
import tempfile

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
        description="Regenerate categorical COGs with NEAREST resampling",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Detection Methods:
  By default, uses both analysis_type field AND colormap analysis.
  Use --no-analysis-type to rely solely on colormap characteristics.
  
Examples:
  # Standard: Use both detection methods
  python regenerate_categorical_cogs.py --dry-run
  
  # Only colormap analysis (ignore analysis_type field)
  python regenerate_categorical_cogs.py --no-analysis-type --dry-run
  
  # Stricter colormap detection
  python regenerate_categorical_cogs.py --min-confidence=0.8
        """
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
    print(f"Detection: {'Colormap only' if args.no_analysis_type else 'analysis_type + colormap'}")
    if not args.no_analysis_type:
        print(f"Min Confidence: {args.min_confidence}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    if args.filter:
        print(f"Filter: {args.filter}")
    if args.limit:
        print(f"Limit: {args.limit} file(s)")
    print()
    
    # Get categorical tables from database
    print("Querying database for categorical layers...")
    use_analysis_type = not args.no_analysis_type
    tables = get_categorical_layer_tables(
        use_analysis_type=use_analysis_type,
        min_confidence=args.min_confidence
    )
    
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
        print("DRY RUN - Would regenerate these files:")
        print("=" * 80)
        for key in keys[:10]:
            print(f"  {key}")
        if len(keys) > 10:
            print(f"  ... and {len(keys) - 10} more")
        print()
        print("To run for real, remove --dry-run flag")
        return
    
    # Write keys to temporary file for management script
    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        keys_file = f.name
        for key in keys:
            f.write(f"{key}\n")
    
    print(f"\nKeys written to temporary file: {keys_file}")
    
    # Call manage_cog_conversion.py regenerate command
    manage_script = os.path.join(script_dir, "manage_cog_conversion.py")
    
    if not os.path.exists(manage_script):
        print(f"ERROR: manage_cog_conversion.py not found at {manage_script}")
        sys.exit(1)
    
    cmd = [
        sys.executable,
        manage_script,
        "regenerate",
        "--keys-file", keys_file,
        "--overview-resampling", "NEAREST",
        "--overwrite",
    ]
    
    print("\n" + "=" * 80)
    print("Submitting AWS Batch jobs...")
    print("=" * 80)
    print(f"Command: {' '.join(cmd)}")
    print()
    
    try:
        result = subprocess.run(cmd, check=True)
        
        print("\n" + "=" * 80)
        print("SUCCESS: Batch jobs submitted!")
        print("=" * 80)
        print(f"Submitted jobs to regenerate {len(keys)} COG file(s)")
        print(f"Overview resampling: NEAREST")
        print("\nMonitor progress:")
        print(f"  S3_BUCKET={s3_bucket} python manage_cog_conversion.py jobs")
        print("\nAfter completion:")
        print("  1. Clear browser cache")
        print("  2. Reload staging site")
        print("  3. Check land cover layers at zoom 3-8")
        print("  4. Verify clean boundaries (no noise)")
        
    except subprocess.CalledProcessError as e:
        print(f"\nERROR: Failed to submit batch jobs (exit code {e.returncode})")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print("\n\nAborted by user.")
        sys.exit(1)
    finally:
        # Clean up temporary file
        try:
            os.unlink(keys_file)
        except:
            pass


if __name__ == "__main__":
    main()
