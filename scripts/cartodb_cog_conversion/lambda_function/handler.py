"""
COG Conversion Lambda Function

Converts GeoTIFF files to Cloud-Optimized GeoTIFFs (COGs) using GDAL.
Downloads from S3, converts, and uploads to a new prefix.
"""

import os
import json
import subprocess
import tempfile
import logging
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# S3 client
s3_client = boto3.client('s3')


def lambda_handler(event, context):
    """
    Lambda handler for COG conversion.
    
    Expected event format:
    {
        "source_bucket": "my-bucket",
        "source_key": "cartodb-rasters/schema_table.tif",
        "dest_bucket": "my-bucket",  # optional, defaults to source_bucket
        "dest_prefix": "cartodb-cogs/",  # optional, defaults to cartodb-cogs/
        "compression": "LZW",  # optional, defaults to LZW
        "overwrite": false  # optional, skip if COG exists
    }
    
    Can also process batch:
    {
        "batch": [
            {"source_key": "path/to/file1.tif"},
            {"source_key": "path/to/file2.tif"}
        ],
        "source_bucket": "my-bucket",
        "dest_bucket": "my-bucket",
        "dest_prefix": "cartodb-cogs/"
    }
    """
    logger.info(f"Received event: {json.dumps(event)}")
    
    # Handle batch processing
    if 'batch' in event:
        results = []
        for item in event['batch']:
            item_event = {**event, **item}
            del item_event['batch']
            result = process_single_tiff(item_event)
            results.append(result)
        
        success_count = sum(1 for r in results if r.get('status') == 'success')
        skip_count = sum(1 for r in results if r.get('status') == 'skipped')
        fail_count = sum(1 for r in results if r.get('status') == 'error')
        
        return {
            'statusCode': 200,
            'body': {
                'message': f'Batch complete: {success_count} converted, {skip_count} skipped, {fail_count} failed',
                'results': results
            }
        }
    
    # Single file processing
    return process_single_tiff(event)


def process_single_tiff(event):
    """Process a single TIFF file."""
    source_bucket = event.get('source_bucket')
    source_key = event.get('source_key')
    dest_bucket = event.get('dest_bucket', source_bucket)
    dest_prefix = event.get('dest_prefix', 'cartodb-cogs/')
    compression = event.get('compression', 'LZW')
    overwrite = event.get('overwrite', False)
    
    if not source_bucket or not source_key:
        return {
            'status': 'error',
            'source_key': source_key,
            'error': 'Missing required parameters: source_bucket and source_key'
        }
    
    # Ensure dest_prefix ends with /
    if dest_prefix and not dest_prefix.endswith('/'):
        dest_prefix += '/'
    
    # Build destination key
    filename = Path(source_key).name
    # Add _cog suffix before extension
    stem = Path(filename).stem
    dest_key = f"{dest_prefix}{stem}_cog.tif"
    
    logger.info(f"Processing: s3://{source_bucket}/{source_key} -> s3://{dest_bucket}/{dest_key}")
    
    # Check if COG already exists
    if not overwrite:
        if s3_object_exists(dest_bucket, dest_key):
            logger.info(f"COG already exists, skipping: {dest_key}")
            return {
                'status': 'skipped',
                'source_key': source_key,
                'dest_key': dest_key,
                'message': 'COG already exists'
            }
    
    # Create temp directory for processing
    with tempfile.TemporaryDirectory() as tmpdir:
        input_path = os.path.join(tmpdir, 'input.tif')
        output_path = os.path.join(tmpdir, 'output_cog.tif')
        
        try:
            # Download source TIFF
            logger.info(f"Downloading {source_key}...")
            s3_client.download_file(source_bucket, source_key, input_path)
            
            input_size = os.path.getsize(input_path)
            logger.info(f"Downloaded {input_size} bytes")
            
            # Convert to COG using gdal_translate
            logger.info(f"Converting to COG with {compression} compression...")
            result = convert_to_cog(input_path, output_path, compression)
            
            if not result['success']:
                return {
                    'status': 'error',
                    'source_key': source_key,
                    'error': result['error']
                }
            
            output_size = os.path.getsize(output_path)
            logger.info(f"COG created: {output_size} bytes")
            
            # Upload COG to S3
            logger.info(f"Uploading to s3://{dest_bucket}/{dest_key}...")
            s3_client.upload_file(
                output_path, 
                dest_bucket, 
                dest_key,
                ExtraArgs={
                    'ContentType': 'image/tiff',
                    'Metadata': {
                        'source-key': source_key,
                        'cog-compression': compression
                    }
                }
            )
            
            return {
                'status': 'success',
                'source_key': source_key,
                'dest_key': dest_key,
                'source_size': input_size,
                'cog_size': output_size,
                'compression_ratio': round(input_size / output_size, 2) if output_size > 0 else 0
            }
            
        except ClientError as e:
            error_msg = str(e)
            logger.error(f"S3 error: {error_msg}")
            return {
                'status': 'error',
                'source_key': source_key,
                'error': f"S3 error: {error_msg}"
            }
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Unexpected error: {error_msg}")
            return {
                'status': 'error',
                'source_key': source_key,
                'error': error_msg
            }


def convert_to_cog(input_path, output_path, compression='LZW'):
    """
    Convert a GeoTIFF to Cloud-Optimized GeoTIFF using GDAL 3.9+.
    
    Uses native COG driver with optimal settings for cloud streaming.
    """
    # COG creation options for GDAL 3.1+ native COG driver
    # - COMPRESS: LZW, DEFLATE, ZSTD, JPEG, WEBP, NONE
    # - PREDICTOR: YES auto-selects best predictor for data type
    # - BLOCKSIZE: 512 is standard for COG (good balance of size/requests)
    # - OVERVIEWS: AUTO generates overviews automatically
    # - BIGTIFF: IF_SAFER handles files > 4GB automatically
    
    cmd = [
        'gdal_translate',
        '-of', 'COG',
        '-co', f'COMPRESS={compression}',
        '-co', 'PREDICTOR=YES',
        '-co', 'BLOCKSIZE=512',
        '-co', 'OVERVIEWS=IGNORE_EXISTING',
        '-co', 'OVERVIEW_RESAMPLING=AVERAGE',
        '-co', 'BIGTIFF=IF_SAFER',
        '-co', 'NUM_THREADS=ALL_CPUS',
        input_path,
        output_path
    ]
    
    logger.info(f"Running: {' '.join(cmd)}")
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=600  # 10 minute timeout
        )
        
        if result.returncode != 0:
            return {
                'success': False,
                'error': f"gdal_translate failed: {result.stderr}"
            }
        
        # Verify output is valid COG
        if os.path.exists(output_path) and os.path.getsize(output_path) > 0:
            return {'success': True}
        else:
            return {
                'success': False,
                'error': 'Output file not created or empty'
            }
            
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'error': 'Conversion timed out after 10 minutes'
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }


def s3_object_exists(bucket, key):
    """Check if an S3 object exists."""
    try:
        s3_client.head_object(Bucket=bucket, Key=key)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return False
        raise


def validate_cog(file_path):
    """
    Validate that a file is a valid COG.
    Returns dict with validation results.
    """
    # Use rio-cogeo or gdalinfo to validate
    cmd = ['gdalinfo', '-json', file_path]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        if result.returncode != 0:
            return {'valid': False, 'error': result.stderr}
        
        info = json.loads(result.stdout)
        
        # Check for tiling
        has_tiling = 'BLOCK_SIZE' in str(info) or 'blockSize' in str(info)
        
        # Check for overviews
        has_overviews = 'overviews' in str(info).lower()
        
        return {
            'valid': True,
            'has_tiling': has_tiling,
            'has_overviews': has_overviews,
            'driver': info.get('driverShortName', 'unknown'),
            'size': info.get('size', []),
            'bands': len(info.get('bands', []))
        }
        
    except Exception as e:
        return {'valid': False, 'error': str(e)}
