# COG Conversion - Cloud-Optimized GeoTIFF Converter

Converts raw GeoTIFFs from S3 to Cloud-Optimized GeoTIFFs (COGs) using AWS Batch with GDAL 3.9.

## Overview

This tool:
1. Lists all raw TIFFs in an S3 prefix (e.g., `cartodb_exports/rasters/`)
2. Optionally filters by filename regex pattern
3. Checks which have already been converted to COGs (in `cartodb_exports/cogs/`)
4. Submits AWS Batch jobs to convert only the pending ones
5. Tracks progress and can resume interrupted conversions (spot instance friendly)
6. Supports dry-run mode to preview what would be converted

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Management     │────▶│  AWS Batch      │────▶│  S3 Bucket      │
│  Script         │     │  (GDAL 3.9)     │     │                 │
│  (Python/boto3) │     │                 │     │  cartodb_exports/
│                 │     │  - Spot/EC2     │     │  └── rasters/   │
│  - setup        │     │  - Resume OK    │     │      └── *.tif  │
│  - deploy       │     │  - No timeout   │     │                 │
│  - status       │     │  - Manifest jobs│     │  └── cogs/      │
│  - convert      │     │                 │     │      └── *_cog.tif
│  - jobs         │     └─────────────────┘     └─────────────────┘
└─────────────────┘

Each Batch job processes ~50 TIFFs from a manifest file.
Jobs skip already-converted files (resume support).
Spot instances provide 60-90% cost savings.
```

## Why AWS Batch Instead of Lambda?

| Feature | Lambda | AWS Batch |
|---------|--------|-----------|
| Max timeout | 15 minutes | Unlimited |
| Max memory | 10 GB | 500+ GB |
| Max storage | 10 GB /tmp | EBS volumes |
| Cost for 2000 files | ~$100+ | ~$5-10 (spot) |
| Container size | Matters (startup) | Doesn't matter |
| Resume on interrupt | Complex | Built-in |
| Spot instance support | No | Yes (60-90% savings) |

## Prerequisites

- Python 3 with boto3 (`pip install boto3`)
- AWS CLI configured with appropriate permissions
- Docker (for building container image)

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
                "batch:*",
                "ecr:*",
                "ecs:*",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups"
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
                "iam:PassRole",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile"
            ],
            "Resource": "*"
        }
    ]
}
```

## Quick Start

```powershell
# 1. Set environment variables
$env:S3_BUCKET = "resilienceatlas"
$env:SOURCE_PREFIX = "cartodb_exports/rasters/"
$env:COG_PREFIX = "cartodb_exports/cogs/"
$env:AWS_REGION = "us-east-1"
$env:AWS_PROFILE = "resilienceatlas"  # Optional

# 2. Set up AWS Batch infrastructure (first time only)
python manage_cog_conversion.py setup

# 3. Build and deploy the Docker image
python manage_cog_conversion.py deploy

# 4. Check current status
python manage_cog_conversion.py status

# 5. Submit batch jobs for all pending TIFFs
python manage_cog_conversion.py convert

# 6. Monitor job progress
python manage_cog_conversion.py jobs
```

## Commands

### `setup` - Set Up AWS Batch Infrastructure

Creates all necessary AWS resources:
- ECR repository for Docker image
- IAM roles (Batch service, ECS instance, job execution)
- Batch compute environment (with spot instances by default)
- Batch job queue

```powershell
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py setup
```

### `deploy` - Deploy Container Image

Builds and pushes the GDAL Docker image, then creates/updates the job definition.

```powershell
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py deploy
```

This:
1. Builds Docker image with GDAL 3.9
2. Pushes to ECR
3. Creates/updates Batch job definition

### `list` - List Raw TIFFs

Lists all GeoTIFF files in the source S3 prefix.

```powershell
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py list
```

Output saved to: `cog_status/raw_tiffs.txt`

### `status` - Show Conversion Status

Shows how many TIFFs are raw, converted, and pending.

```powershell
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py status
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
Estimated jobs: 47 (at 50 files/job)
```

### `convert` - Submit Batch Jobs

Submits AWS Batch jobs for all pending TIFFs.

```powershell
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py convert
```

Options via environment variables:
- `FILES_PER_JOB=50` - TIFFs per Batch job
- `MAX_VCPUS=16` - Maximum concurrent vCPUs
- `JOB_VCPUS=2` - vCPUs per job
- `JOB_MEMORY=4096` - Memory (MB) per job
- `USE_SPOT=true` - Use spot instances (60-90% cheaper)
- `COMPRESSION=LZW` - COG compression (LZW, DEFLATE, ZSTD)
- `OVERWRITE=false` - Skip existing COGs
- `RASTER_TYPE=both` - Filter by type: `public`, `cdb_importer`, or `both`
- `FILENAME_FILTER` - Regex to filter which files to process
- `DRY_RUN=true` - Preview what would be submitted

### `jobs` - Monitor Job Status

Shows the status of submitted Batch jobs.

```powershell
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py jobs
```

Example output:
```
================================================================================
Batch Job Status
================================================================================
Total jobs: 47
  SUCCEEDED: 35
  RUNNING: 8
  RUNNABLE: 4
--------------------------------------------------------------------------------
Job Name                                      Files    Status
--------------------------------------------------------------------------------
cog-converter-20240115120000-1                50       SUCCEEDED
cog-converter-20240115120000-2                50       SUCCEEDED
cog-converter-20240115120000-3                50       RUNNING
...
================================================================================
```

## Resume Support

AWS Batch with spot instances may terminate jobs at any time. The system handles this gracefully:

1. **Manifest-based jobs**: Each job receives a manifest of files to process
2. **Skip existing**: Before converting, each file checks if COG already exists
3. **Continue on failure**: If one file fails, the job continues with remaining files
4. **Re-run convert**: Simply run `convert` again to resubmit jobs for remaining files

```powershell
# First run - submits 47 jobs for 2321 files
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py convert

# Spot interruption occurs, 10 jobs failed

# Check status - shows 1500 converted, 821 pending
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py status

# Re-run - submits only 17 jobs for remaining 821 files
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py convert
```

## Dry-Run Mode

Preview what would be submitted without making any changes:

```powershell
$env:S3_BUCKET = "resilienceatlas"
$env:DRY_RUN = "true"
python manage_cog_conversion.py convert
```

Combine with raster type filter:
```powershell
$env:S3_BUCKET = "resilienceatlas"
$env:DRY_RUN = "true"
$env:RASTER_TYPE = "public"
python manage_cog_conversion.py convert
```

## Raster Type Filtering

Source rasters from CartoDB have two naming conventions:
- `public_*` - Tables from the public schema
- `cdb_importer_*` - Tables from CartoDB's importer schema

You can process specific types:

```powershell
# Only public schema rasters
$env:S3_BUCKET = "resilienceatlas"
$env:RASTER_TYPE = "public"
python manage_cog_conversion.py convert

# Only cdb_importer rasters
$env:RASTER_TYPE = "cdb_importer"
python manage_cog_conversion.py convert

# Both types (default)
$env:RASTER_TYPE = "both"
python manage_cog_conversion.py convert
```

**Note**: The `public_` and `cdb_importer_` prefixes are automatically stripped from output filenames:
- `public_rainfall_data.tif` → `rainfall_data.tif`
- `cdb_importer_12345_population.tif` → `12345_population.tif`

**Important**: `SOURCE_PREFIX` and `COG_PREFIX` must be different to prevent overwriting source files.

## Additional Filename Filtering

For more specific filtering, use a regex pattern:

```powershell
# Files containing "africa" or "asia"
$env:S3_BUCKET = "resilienceatlas"
$env:FILENAME_FILTER = "africa|asia"
python manage_cog_conversion.py convert

# Files with year 2024 in name
$env:FILENAME_FILTER = ".*_2024.*"
python manage_cog_conversion.py convert
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_BUCKET` | (required) | S3 bucket name |
| `SOURCE_PREFIX` | `cartodb_exports/rasters/` | S3 prefix for raw TIFFs |
| `COG_PREFIX` | `cartodb_exports/cogs/` | S3 prefix for COGs |
| `AWS_REGION` | `us-east-1` | AWS region |
| `AWS_PROFILE` | (default profile) | AWS credentials profile name |

### Batch Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPUTE_ENV_NAME` | `cog-converter-env` | Batch compute environment name |
| `JOB_QUEUE_NAME` | `cog-converter-queue` | Batch job queue name |
| `JOB_DEFINITION_NAME` | `cog-converter-job` | Batch job definition name |
| `ECR_REPO_NAME` | `cog-converter` | ECR repository name |

### Processing Options

| Variable | Default | Description |
|----------|---------|-------------|
| `FILES_PER_JOB` | `50` | TIFFs per Batch job |
| `MAX_VCPUS` | `16` | Max concurrent vCPUs in compute env |
| `JOB_VCPUS` | `2` | vCPUs allocated per job |
| `JOB_MEMORY` | `4096` | Memory (MB) per job |
| `USE_SPOT` | `true` | Use spot instances |
| `COMPRESSION` | `LZW` | COG compression algorithm |
| `OVERWRITE` | `false` | Overwrite existing COGs |
| `RASTER_TYPE` | `both` | Filter by type: `public`, `cdb_importer`, or `both` |
| `FILENAME_FILTER` | (none) | Regex to filter filenames |
| `DRY_RUN` | `false` | Preview mode, no execution |

## CRS (Coordinate Reference System) Handling

The pipeline requires valid CRS metadata on source files:

1. **Raster Export** - Source SRID from PostgreSQL is written to exported TIFFs using `EPSG:{srid}`
2. **COG Conversion** - Source CRS is read and preserved in the output COG
3. **Validation** - **Conversion fails if source file has no CRS defined**
4. **Verification** - Conversion fails if output CRS doesn't match source CRS

### Missing CRS

If source TIFFs are missing CRS metadata, the conversion will fail with an error. Fix the source raster export to include proper SRID before converting to COG.

To check if a file has CRS:

```powershell
gdalinfo source.tif | Select-String "Coordinate System"
```

If the CRS is missing and you know what it should be, assign it with:

```powershell
gdal_edit.py -a_srs EPSG:4326 source.tif
```

**Note**: `gdal_edit.py -a_srs` assigns the CRS without reprojecting. If you need to reproject data, use `gdalwarp` instead.

## COG Compression Options

| Algorithm | Ratio | Speed | Use Case |
|-----------|-------|-------|----------|
| `LZW` | Good | Fast | Default, general purpose |
| `DEFLATE` | Better | Slower | Smaller files, archival |
| `ZSTD` | Best | Fast | Best compression with GDAL 3.9 |

```powershell
# Use ZSTD for best compression (recommended with GDAL 3.9)
$env:S3_BUCKET = "resilienceatlas"
$env:COMPRESSION = "ZSTD"
python manage_cog_conversion.py convert
```

## Output Structure

### Status Files

```
cog_status/
├── raw_tiffs.txt              # All raw TIFFs: key<TAB>size
├── existing_cogs.txt          # COGs already in destination
├── pending_conversions.txt    # TIFFs awaiting conversion
├── submitted_jobs.json        # Submitted Batch job info
└── cog_conversion.log         # Detailed log
```

### S3 Structure

```
s3://resilienceatlas/
├── cartodb_exports/
│   ├── rasters/               # Source raw TIFFs
│   │   ├── raster1.tif
│   │   └── raster2.tif
│   ├── cogs/                  # Converted COGs
│   │   ├── raster1_cog.tif
│   │   └── raster2_cog.tif
│   └── cogs/manifests/        # Job manifests
│       └── cog-converter-*.json
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

## Docker Image Details

Uses GDAL 3.9 from the official OSGEO image:

```dockerfile
FROM ghcr.io/osgeo/gdal:ubuntu-small-3.9.3

RUN pip3 install --no-cache-dir --break-system-packages boto3

COPY batch_handler.py /app/
ENTRYPOINT [ "python3", "/app/batch_handler.py" ]
```

This provides:
- Native COG driver with all options (ZSTD, multithreading)
- BIGTIFF support for files >4GB
- NUM_THREADS=ALL_CPUS for parallel compression
- No container size concerns (unlike Lambda)

## Cost Estimate

With spot instances (default):
- Compute: ~$0.01-0.02 per vCPU-hour
- 2000 TIFFs at 50/job = 40 jobs
- 5 minutes average per job, 2 vCPUs
- Total: ~$5-10

With on-demand instances:
- 3-4x spot pricing
- Total: ~$15-30

Compare to Lambda (~$100+ for same workload).

## Troubleshooting

### View Batch Job Logs

```powershell
# Get job ID from jobs command output
$env:S3_BUCKET = "resilienceatlas"; python manage_cog_conversion.py jobs

# View CloudWatch logs
aws logs tail /aws/batch/job --follow
```

### Compute Environment Issues

```powershell
# Check compute environment status
aws batch describe-compute-environments --compute-environments cog-converter-env

# Check job queue
aws batch describe-job-queues --job-queues cog-converter-queue
```

### ECR Login Issues

```powershell
# Manual ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com
```

### Spot Instance Terminations

Spot interruptions are normal. The system handles them:
1. Job is terminated by AWS
2. Job enters FAILED state with "Spot instance termination" reason
3. Run `status` to see how many files are pending
4. Run `convert` to resubmit jobs for remaining files

### S3 Permission Errors

Ensure job role has access to bucket:
```powershell
aws iam get-role-policy --role-name cog-converter-job-role --policy-name S3Access
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
- [AWS Batch Documentation](https://docs.aws.amazon.com/batch/)
- [TiTiler](https://developmentseed.org/titiler/)
