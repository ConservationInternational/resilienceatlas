# COG Conversion - Cloud-Optimized GeoTIFF Converter

Converts raw GeoTIFFs from S3 to Cloud-Optimized GeoTIFFs (COGs) using AWS Lambda with GDAL 3.9.

## Overview

This tool:
1. Lists all raw TIFFs in an S3 prefix (e.g., `cartodb_exports/rasters/`)
2. Optionally filters by filename regex pattern
3. Checks which have already been converted to COGs (in `cartodb_exports/cogs/`)
4. Invokes AWS Lambda to convert only the pending ones
5. Tracks progress and can resume interrupted conversions
6. Supports dry-run mode to preview what would be converted

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Management     │────▶│  AWS Lambda     │────▶│  S3 Bucket      │
│  Script         │     │  (GDAL 3.9)     │     │                 │
│  (Python/boto3) │     │                 │     │  cartodb_exports/
│                 │     │  - Download     │     │  └── rasters/   │
│  - list         │     │  - Convert COG  │     │      └── *.tif  │
│  - status       │     │  - Upload       │     │                 │
│  - convert      │     │                 │     │  └── cogs/      │
│  - deploy       │     │                 │     │      └── *_cog.tif
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Prerequisites

- Python 3 with boto3 (`apt install python3-boto3` or `pip install boto3`)
- AWS CLI configured with appropriate permissions
- Docker (for building Lambda image)

### Required AWS Permissions

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:HeadObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR-BUCKET",
                "arn:aws:s3:::YOUR-BUCKET/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration",
                "lambda:InvokeFunction",
                "lambda:GetFunction"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:CreateRepository",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:AttachRolePolicy",
                "iam:PutRolePolicy",
                "iam:GetRole",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
```

## Quick Start

```bash
# 1. Set environment variables
export S3_BUCKET=resilienceatlas
export SOURCE_PREFIX=cartodb_exports/rasters/
export COG_PREFIX=cartodb_exports/cogs/
export AWS_REGION=us-east-1

# Optional: Use a specific AWS credentials profile
export AWS_PROFILE=resilienceatlas

# 2. Check current status
python3 manage_cog_conversion.py status

# 3. Deploy Lambda function (first time only)
python3 manage_cog_conversion.py deploy

# 4. Convert all pending TIFFs
python3 manage_cog_conversion.py convert
```

## Commands

### `list` - List Raw TIFFs

Lists all GeoTIFF files in the source S3 prefix.

```bash
S3_BUCKET=resilienceatlas python3 manage_cog_conversion.py list
```

Output saved to: `cog_status/raw_tiffs.txt`

### `status` - Show Conversion Status

Shows how many TIFFs are raw, converted, and pending.

```bash
S3_BUCKET=resilienceatlas python3 manage_cog_conversion.py status
```

Example output:
```
============================================================
COG Conversion Status
============================================================
Source:      s3://resilienceatlas/cartodb_exports/rasters/
Destination: s3://resilienceatlas/cartodb_exports/cogs/
------------------------------------------------------------
Total raw TIFFs:          2321
Existing COGs:               0
Already converted:           0
Pending conversion:       2321
Progress:                 0.0%
============================================================

Pending data size: 47.50 GB
```

### `convert` - Convert Pending TIFFs

Converts all TIFFs that don't have corresponding COGs.

```bash
S3_BUCKET=resilienceatlas python3 manage_cog_conversion.py convert
```

Options via environment variables:
- `BATCH_SIZE=10` - TIFFs per Lambda invocation
- `PARALLEL_INVOCATIONS=5` - Concurrent Lambda calls
- `COMPRESSION=LZW` - COG compression (LZW, DEFLATE, ZSTD)
- `OVERWRITE=false` - Skip existing COGs
- `FILENAME_FILTER` - Regex to filter which files to process
- `DRY_RUN=true` - Preview what would be converted without executing

### Dry-Run Mode

Preview what would be converted without making any changes:

```bash
S3_BUCKET=resilienceatlas DRY_RUN=true python3 manage_cog_conversion.py convert
```

Combine with filename filter to preview a subset:
```bash
S3_BUCKET=resilienceatlas DRY_RUN=true FILENAME_FILTER="^public_" python3 manage_cog_conversion.py convert
```

### Filename Filtering

Process only files matching a regex pattern:

```bash
# Only files starting with "public_"
S3_BUCKET=resilienceatlas FILENAME_FILTER="^public_" python3 manage_cog_conversion.py convert

# Files containing "africa" or "asia"
S3_BUCKET=resilienceatlas FILENAME_FILTER="africa|asia" python3 manage_cog_conversion.py convert

# Files with year 2024 in name
S3_BUCKET=resilienceatlas FILENAME_FILTER=".*_2024.*" python3 manage_cog_conversion.py convert
```

### `convert-one` - Convert Single TIFF

Convert a specific TIFF file.

```bash
S3_BUCKET=resilienceatlas python3 manage_cog_conversion.py convert-one cartodb_exports/rasters/my_raster.tif
```

### `deploy` - Deploy Lambda Function

Builds and deploys the GDAL Lambda function to AWS.

```bash
S3_BUCKET=resilienceatlas python3 manage_cog_conversion.py deploy
```

This:
1. Creates ECR repository for Docker image
2. Builds GDAL Docker image
3. Pushes to ECR
4. Creates/updates Lambda function
5. Sets up IAM role with S3 permissions

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_BUCKET` | (required) | S3 bucket name |
| `SOURCE_PREFIX` | `cartodb_exports/rasters/` | S3 prefix for raw TIFFs |
| `COG_PREFIX` | `cartodb_exports/cogs/` | S3 prefix for COGs |
| `AWS_REGION` | `us-east-1` | AWS region |
| `AWS_PROFILE` | (default profile) | AWS credentials profile name |

### Lambda Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LAMBDA_FUNCTION_NAME` | `cog-converter` | Lambda function name |
| `LAMBDA_MEMORY` | `3008` | Memory in MB (affects CPU) |
| `LAMBDA_TIMEOUT` | `900` | Timeout in seconds (max 15 min) |

### Processing Options

| Variable | Default | Description |
|----------|---------|-------------|
| `BATCH_SIZE` | `10` | TIFFs per Lambda invocation |
| `PARALLEL_INVOCATIONS` | `5` | Concurrent Lambda calls |
| `COMPRESSION` | `LZW` | COG compression algorithm |
| `OVERWRITE` | `false` | Overwrite existing COGs |
| `FILENAME_FILTER` | (none) | Regex to filter filenames |
| `DRY_RUN` | `false` | Preview mode, no execution |

## COG Compression Options

| Algorithm | Ratio | Speed | Use Case |
|-----------|-------|-------|----------|
| `LZW` | Good | Fast | Default, general purpose |
| `DEFLATE` | Better | Slower | Smaller files, archival |
| `ZSTD` | Best | Fast | Best compression with GDAL 3.9 |

```bash
# Use ZSTD for best compression (recommended with GDAL 3.9)
S3_BUCKET=resilienceatlas COMPRESSION=ZSTD python3 manage_cog_conversion.py convert
```

## Output Structure

### Status Files

```
cog_status/
├── raw_tiffs.txt              # All raw TIFFs: key<TAB>size
├── existing_cogs.txt          # COGs already in destination
├── pending_conversions.txt    # TIFFs awaiting conversion
├── completed_conversions.txt  # Successfully converted
├── failed_conversions.txt     # Failed: key<TAB>error
└── cog_conversion.log         # Detailed log
```

### S3 Structure

```
s3://resilienceatlas/
├── cartodb_exports/
│   ├── rasters/               # Source raw TIFFs
│   │   ├── raster1.tif
│   │   └── raster2.tif
│   └── cogs/                  # Converted COGs
│       ├── raster1_cog.tif
│       └── raster2_cog.tif
```

## What is a COG?

Cloud-Optimized GeoTIFF (COG) is a regular GeoTIFF with:
- **Internal tiling** (512x512 blocks) for partial reads
- **Overviews** (pyramids) for quick preview at any zoom
- **Proper byte ordering** for HTTP range requests

Benefits:
- Efficient streaming from S3/cloud storage
- No need to download entire file
- Works with TiTiler, QGIS, and other modern GIS tools

## Lambda Function Details

### Docker Image

Uses GDAL 3.9 from the official OSGEO image, combined with AWS Lambda Python 3.12 runtime:

```dockerfile
FROM ghcr.io/osgeo/gdal:ubuntu-small-3.9.3 AS gdal-base
FROM public.ecr.aws/lambda/python:3.12

# Copy GDAL binaries and libraries from osgeo image
COPY --from=gdal-base /usr/bin/gdal* /usr/local/bin/
COPY --from=gdal-base /usr/lib/x86_64-linux-gnu/libgdal* /usr/lib/x86_64-linux-gnu/
# ... additional libraries
```

This provides:
- Native COG driver with all options (ZSTD, multithreading)
- BIGTIFF support for files >4GB
- NUM_THREADS=ALL_CPUS for parallel compression

### Memory and Performance

| TIFF Size | Recommended Memory | Timeout |
|-----------|-------------------|---------|
| < 100 MB  | 1024 MB           | 5 min   |
| 100-500 MB| 2048 MB           | 10 min  |
| 500 MB+   | 3008+ MB          | 15 min  |

Lambda CPU scales with memory allocation.

### Cost Estimate

At 3008 MB memory, 5-minute execution:
- Per invocation: ~$0.015
- 1000 TIFFs: ~$15

## Troubleshooting

### Lambda Timeout

For very large TIFFs (>1 GB), you may need to:
1. Increase Lambda memory: `LAMBDA_MEMORY=10240`
2. Consider using EC2 or ECS for batch processing

### Deployment Errors

```bash
# Check Lambda status
aws lambda get-function --function-name cog-converter

# View Lambda logs
aws logs tail /aws/lambda/cog-converter --follow

# Test Lambda directly
S3_BUCKET=resilienceatlas python3 manage_cog_conversion.py convert-one cartodb_exports/rasters/test.tif
```

### S3 Permission Errors

Ensure Lambda role has access to both source and destination prefixes:
```bash
aws iam get-role-policy --role-name cog-converter-role --policy-name S3Access
```

## Integration with TiTiler

Once COGs are in S3, they can be served directly via TiTiler:

```
GET /cog/tiles/{z}/{x}/{y}?url=s3://resilienceatlas/cartodb_exports/cogs/raster_cog.tif
```

No additional processing needed - COGs are ready for streaming.

## See Also

- [COG Specification](https://www.cogeo.org/)
- [GDAL COG Driver](https://gdal.org/drivers/raster/cog.html)
- [TiTiler](https://developmentseed.org/titiler/)
- [rio-cogeo](https://cogeotiff.github.io/rio-cogeo/)
