#!/usr/bin/env python3
"""
AWS Batch handler for COG conversion.

This script is invoked by AWS Batch jobs. It:
1. Receives a list of S3 keys to process (via environment variable or file)
2. Checks which COGs already exist (skip logic for resume)
3. Downloads each TIFF, converts to COG, uploads result
4. Handles failures gracefully, continuing with remaining files
5. Preserves and verifies CRS (Coordinate Reference System) throughout the pipeline
6. Fails if source file has no CRS defined

Environment variables:
    S3_BUCKET: S3 bucket name
    SOURCE_PREFIX: Source prefix for raw TIFFs
    COG_PREFIX: Destination prefix for COGs
    COMPRESSION: COG compression (LZW, DEFLATE, ZSTD)
    OVERVIEW_RESAMPLING: Resampling for overviews (NEAREST, AVERAGE, BILINEAR, CUBIC)
                        Use NEAREST for categorical data (land cover, zones)
                        Use AVERAGE/BILINEAR for continuous data (temperature, precipitation)
    TIFF_KEYS: Comma-separated list of S3 keys to process
    MANIFEST_KEY: S3 key to a manifest file listing keys to process
    OVERWRITE: Whether to overwrite existing COGs (true/false)
"""

import json
import os
import subprocess
import sys
import tempfile
import traceback
from datetime import datetime

import boto3


def log(level: str, message: str):
    """Log with timestamp."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {level}: {message}", flush=True)


def info(message: str):
    log("INFO", message)


def error(message: str):
    log("ERROR", message)


def get_s3_client():
    """Get S3 client."""
    return boto3.client("s3")


def get_raster_epsg(filepath: str) -> str:
    """Return the EPSG code embedded in a raster file (e.g. 'EPSG:3857'), or ''.

    Prefer GDAL's structured CRS id when present. If it is missing, fall back
    to parsing the WKT and use the last CRS identifier rather than nested unit
    or base-geography identifiers.
    """
    import re as _re
    try:
        result = subprocess.run(
            ["gdalinfo", "-json", filepath],
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode != 0:
            return ""
        coordinate_system = json.loads(result.stdout).get("coordinateSystem", {})

        projjson_id = coordinate_system.get("projjson", {}).get("id", {})
        if projjson_id.get("authority") == "EPSG" and projjson_id.get("code"):
            return f"EPSG:{projjson_id['code']}"

        wkt = coordinate_system.get("wkt", "")

        # Prefer WKT2's top-level ID tags when present; otherwise fall back to
        # WKT1 AUTHORITY tags and take the last match, which is the outermost CRS.
        for pattern in (r'ID\["EPSG",(\d+)\]', r'AUTHORITY\["EPSG","(\d+)"\]'):
            matches = _re.findall(pattern, wkt)
            if matches:
                return f"EPSG:{matches[-1]}"
    except Exception as e:
        error(f"Failed to read CRS from {filepath}: {e}")
    return ""


def cog_exists(s3_client, bucket: str, cog_key: str) -> bool:
    """Check if a COG already exists in S3."""
    try:
        s3_client.head_object(Bucket=bucket, Key=cog_key)
        return True
    except s3_client.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "404":
            return False
        raise


def strip_table_prefix(filename: str) -> str:
    """
    Strip CartoDB table prefixes from filename.
    
    Removes 'public_' and 'cdb_importer_' prefixes that come from
    PostgreSQL schema/table naming conventions.
    
    Examples:
        public_rainfall_data.tif -> rainfall_data.tif
        cdb_importer_12345_population.tif -> 12345_population.tif
    """
    for prefix in ["public_", "cdb_importer_"]:
        if filename.startswith(prefix):
            return filename[len(prefix):]
    return filename


def get_expected_cog_key(source_key: str, cog_prefix: str) -> str:
    """Get the expected COG key for a source TIFF, stripping table prefixes."""
    filename = os.path.basename(source_key)
    # Strip table prefixes (public_, cdb_importer_)
    clean_filename = strip_table_prefix(filename)
    return f"{cog_prefix}{clean_filename}"


def convert_to_cog(
    s3_client,
    bucket: str,
    source_key: str,
    cog_prefix: str,
    compression: str = "LZW",
    overview_resampling: str = "AVERAGE",
    overwrite: bool = False,
) -> dict:
    """
    Convert a single TIFF to COG, preserving CRS.
    
    Args:
        s3_client: boto3 S3 client
        bucket: S3 bucket name
        source_key: S3 key of source TIFF
        cog_prefix: S3 prefix for output COGs
        compression: Compression algorithm (LZW, DEFLATE, ZSTD)
        overview_resampling: Resampling method for overviews (NEAREST, AVERAGE, BILINEAR, CUBIC)
                            Use NEAREST for categorical/discrete data (land cover, zones)
                            Use AVERAGE/BILINEAR for continuous data (temperature, precipitation)
        overwrite: Whether to overwrite existing COGs
    
    Returns:
        dict with success, source_key, dest_key, source_crs, and error if failed
    
    Raises:
        Fails if source file has no CRS defined.
    """
    cog_key = get_expected_cog_key(source_key, cog_prefix)
    
    # Check if already converted (skip logic for resume)
    if not overwrite and cog_exists(s3_client, bucket, cog_key):
        info(f"Skipping (already exists): {source_key}")
        return {
            "success": True,
            "source_key": source_key,
            "dest_key": cog_key,
            "skipped": True,
        }
    
    info(f"Converting: {source_key}")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        # Download source TIFF
        source_path = os.path.join(tmpdir, "source.tif")
        cog_path = os.path.join(tmpdir, "output_cog.tif")
        
        try:
            info(f"Downloading from s3://{bucket}/{source_key}")
            s3_client.download_file(bucket, source_key, source_path)
        except Exception as e:
            return {
                "success": False,
                "source_key": source_key,
                "error": f"Download failed: {e}",
            }

        # Read the EPSG code from the source and assign it to the output COG.
        # CartoDB exports embed a broken WKT datum name that PROJ 9+ rejects
        # at tile-serve time; passing -a_srs rewrites it with a clean definition.
        source_epsg = get_raster_epsg(source_path)
        if not source_epsg:
            error(f"Source file has no recognisable CRS: {source_key}")
            return {
                "success": False,
                "source_key": source_key,
                "error": "Source file has no CRS. Fix the export before converting.",
            }
        info(f"Source CRS: {source_epsg}")

        cmd = [
            "gdal_translate",
            "-of", "COG",
            "-co", f"OVERVIEW_RESAMPLING={overview_resampling}",
            "-co", f"COMPRESS={compression}",
            "-co", "BIGTIFF=IF_SAFER",
            "-co", "NUM_THREADS=ALL_CPUS",
            "-co", "OVERVIEWS=AUTO",
            "-a_srs", source_epsg,
            source_path, cog_path,
        ]
        
        try:
            info(f"Running: {' '.join(cmd)}")
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=3600,  # 1 hour timeout per file
            )
            
            if result.returncode != 0:
                return {
                    "success": False,
                    "source_key": source_key,
                    "error": f"gdal_translate failed: {result.stderr}",
                }
                
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "source_key": source_key,
                "error": "gdal_translate timed out after 1 hour",
            }
        except Exception as e:
            return {
                "success": False,
                "source_key": source_key,
                "error": f"gdal_translate error: {e}",
            }
        
        # Upload COG to S3
        try:
            info(f"Uploading to s3://{bucket}/{cog_key}")
            s3_client.upload_file(cog_path, bucket, cog_key)
        except Exception as e:
            return {
                "success": False,
                "source_key": source_key,
                "error": f"Upload failed: {e}",
            }

    info(f"Successfully converted: {source_key} -> {cog_key}")
    return {
        "success": True,
        "source_key": source_key,
        "dest_key": cog_key,
        "source_crs": source_epsg,
        "skipped": False,
    }


def get_keys_to_process(s3_client, bucket: str) -> list[str]:
    """Get list of S3 keys to process from environment."""
    # Option 1: Direct list in environment variable
    tiff_keys = os.environ.get("TIFF_KEYS", "")
    if tiff_keys:
        return [k.strip() for k in tiff_keys.split(",") if k.strip()]
    
    # Option 2: Manifest file in S3
    manifest_key = os.environ.get("MANIFEST_KEY", "")
    if manifest_key:
        info(f"Loading manifest from s3://{bucket}/{manifest_key}")
        with tempfile.NamedTemporaryFile(mode="w+", suffix=".json", delete=False) as f:
            manifest_path = f.name
        
        try:
            s3_client.download_file(bucket, manifest_key, manifest_path)
            with open(manifest_path) as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
                elif isinstance(data, dict) and "keys" in data:
                    return data["keys"]
                else:
                    error(f"Invalid manifest format")
                    return []
        finally:
            if os.path.exists(manifest_path):
                os.remove(manifest_path)
    
    error("No TIFF_KEYS or MANIFEST_KEY specified")
    return []


def main():
    """Main entry point for batch processing."""
    info("Starting COG conversion batch job")
    
    # Get configuration from environment
    bucket = os.environ.get("S3_BUCKET", "")
    if not bucket:
        error("S3_BUCKET not set")
        sys.exit(1)
    
    cog_prefix = os.environ.get("COG_PREFIX", "cartodb_exports/cogs/")
    compression = os.environ.get("COMPRESSION", "LZW")
    overview_resampling = os.environ.get("OVERVIEW_RESAMPLING", "AVERAGE")  # NEAREST for categorical, AVERAGE for continuous
    overwrite = os.environ.get("OVERWRITE", "false").lower() == "true"
    
    info(f"Configuration:")
    info(f"  Bucket: {bucket}")
    info(f"  COG Prefix: {cog_prefix}")
    info(f"  Compression: {compression}")
    info(f"  Overview Resampling: {overview_resampling}")
    info(f"  Overwrite: {overwrite}")
    
    # Get S3 client
    s3_client = get_s3_client()
    
    # Get keys to process
    keys = get_keys_to_process(s3_client, bucket)
    if not keys:
        error("No keys to process")
        sys.exit(1)
    
    info(f"Processing {len(keys)} files")
    
    # Process each file
    results = {
        "total": len(keys),
        "success": 0,
        "skipped": 0,
        "failed": 0,
        "failures": [],
    }
    
    for i, source_key in enumerate(keys, 1):
        info(f"[{i}/{len(keys)}] Processing: {source_key}")
        
        try:
            result = convert_to_cog(
                s3_client,
                bucket,
                source_key,
                cog_prefix,
                compression,
                overview_resampling,
                overwrite,
            )
            
            if result["success"]:
                if result.get("skipped"):
                    results["skipped"] += 1
                else:
                    results["success"] += 1
            else:
                results["failed"] += 1
                results["failures"].append({
                    "key": source_key,
                    "error": result.get("error", "Unknown error"),
                })
                error(f"Failed: {result.get('error')}")
                
        except Exception as e:
            results["failed"] += 1
            results["failures"].append({
                "key": source_key,
                "error": str(e),
            })
            error(f"Exception processing {source_key}: {e}")
            traceback.print_exc()
    
    # Summary
    info("=" * 60)
    info("Batch Job Complete")
    info("=" * 60)
    info(f"Total files:     {results['total']}")
    info(f"Newly converted: {results['success']}")
    info(f"Skipped (exist): {results['skipped']}")
    info(f"Failed:          {results['failed']}")
    info("=" * 60)
    
    if results["failures"]:
        error("Failed files:")
        for f in results["failures"]:
            error(f"  {f['key']}: {f['error']}")
    
    # Exit with error if any failures
    if results["failed"] > 0:
        sys.exit(1)
    
    info("All files processed successfully!")


if __name__ == "__main__":
    main()
