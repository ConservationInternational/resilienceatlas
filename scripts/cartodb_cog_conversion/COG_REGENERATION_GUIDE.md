# COG Regeneration Guide

## Overview

The `manage_cog_conversion.py regenerate` command allows you to regenerate specific COG files with different overview resampling methods. This is useful when:

- Categorical layers need NEAREST resampling (land cover, zones)
- Continuous layers need smoother resampling (AVERAGE, BILINEAR)
- COGs were created with wrong compression or other settings
- You need to reprocess a subset of files

## Architecture

```
┌─────────────────────┐
│ Keys File           │  One S3 key per line
│ (categorical.txt)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ manage_cog_         │  Reads keys file
│ conversion.py       │  Submits AWS Batch jobs
│ regenerate          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ AWS Batch           │  Processes files in parallel
│ (batch_handler.py)  │  Downloads, converts, uploads
│                     │
│ - Spot instances    │  60-90% cost savings
│ - Resume support    │  Can retry failed files
│ - No timeout        │  Unlimited processing time
└─────────────────────┘
```

## Quick Start

### 1. Create Keys File

Create a text file with S3 keys to regenerate (one per line):

```bash
cat > my_keys.txt << EOF
cartodb_exports/rasters/land_cover_2015.tif
cartodb_exports/rasters/land_cover_2020.tif
cartodb_exports/rasters/urban_zones.tif
EOF
```

### 2. Submit Batch Jobs

```bash
export S3_BUCKET=resilienceatlas
export AWS_PROFILE=resilienceatlas

python manage_cog_conversion.py regenerate \
  --keys-file=my_keys.txt \
  --overview-resampling=NEAREST \
  --overwrite
```

### 3. Monitor Progress

```bash
S3_BUCKET=resilienceatlas python manage_cog_conversion.py jobs
```

## Command Reference

### regenerate Command

```bash
python manage_cog_conversion.py regenerate [OPTIONS]
```

**Required Options:**
- `--keys-file=FILE` - File containing S3 keys (one per line)

**Optional:**
- `--overview-resampling=METHOD` - Resampling: NEAREST, AVERAGE, BILINEAR, CUBIC (default: AVERAGE)
- `--overwrite` - Overwrite existing COGs (default: false)

**Environment Variables:**
- `S3_BUCKET` - S3 bucket name (required)
- `AWS_PROFILE` - AWS credentials profile
- `AWS_REGION` - AWS region (default: us-east-1)
- `FILES_PER_JOB` - Files per batch job (default: 50)
- `MAX_VCPUS` - Max concurrent vCPUs (default: 16)
- `DRY_RUN` - Preview without executing (true/false)

## Resampling Methods

### NEAREST (Categorical Data)

**Use for:** Land cover, land use, zones, discrete classifications

**Effect:** Preserves exact pixel values, no interpolation

**Example:**
```bash
python manage_cog_conversion.py regenerate \
  --keys-file=categorical_layers.txt \
  --overview-resampling=NEAREST \
  --overwrite
```

### AVERAGE (Continuous Data)

**Use for:** Temperature, precipitation, elevation, smooth gradients

**Effect:** Averages neighboring pixels, creates smooth overviews

**Example:**
```bash
python manage_cog_conversion.py regenerate \
  --keys-file=temperature_layers.txt \
  --overview-resampling=AVERAGE \
  --overwrite
```

### BILINEAR / CUBIC

**Use for:** High-quality continuous data requiring smooth interpolation

**Effect:** More sophisticated interpolation than AVERAGE

**Note:** CUBIC is slower but produces smoother results

## Common Scenarios

### Scenario 1: Fix Categorical Layers (Automated)

Use the convenience script to find all categorical layers:

```bash
# Generate keys and submit batch jobs
python regenerate_categorical_cogs.py --dry-run  # Preview
python regenerate_categorical_cogs.py            # Submit
```

### Scenario 2: Fix Categorical Layers (Manual)

Query database yourself:

```bash
# Generate list of categorical layer keys
python generate_categorical_tiff_list.py --output=categorical.txt

# Submit batch jobs
python manage_cog_conversion.py regenerate \
  --keys-file=categorical.txt \
  --overview-resampling=NEAREST \
  --overwrite
```

### Scenario 3: Regenerate Specific Layers

Create keys file manually:

```bash
# Create keys file
cat > specific_layers.txt << EOF
cartodb_exports/rasters/layer1.tif
cartodb_exports/rasters/layer2.tif
EOF

# Regenerate with desired resampling
python manage_cog_conversion.py regenerate \
  --keys-file=specific_layers.txt \
  --overview-resampling=NEAREST \
  --overwrite
```

### Scenario 4: Test Before Full Regeneration

Process just a few files first:

```bash
# Create test file with 2-3 keys
head -3 categorical.txt > test.txt

# Process test files
python manage_cog_conversion.py regenerate \
  --keys-file=test.txt \
  --overview-resampling=NEAREST \
  --overwrite

# Verify results on staging
# Then process full list
python manage_cog_conversion.py regenerate \
  --keys-file=categorical.txt \
  --overview-resampling=NEAREST \
  --overwrite
```

## Monitoring & Troubleshooting

### Check Job Status

```bash
# List all jobs with status
S3_BUCKET=resilienceatlas python manage_cog_conversion.py jobs
```

Output shows:
- Job ID and name
- Status (SUBMITTED, PENDING, RUNNING, SUCCEEDED, FAILED)
- File count per job
- Start/stop times

### Failed Jobs

If jobs fail:

1. **Check job logs in AWS Batch console**
2. **Common issues:**
   - Source file missing in S3
   - Invalid CRS in source file
   - Insufficient permissions
   - Network timeout

3. **Retry failed files:**
   - Extract failed keys from logs
   - Create new keys file
   - Submit new batch jobs

### Verify Regeneration

After jobs complete:

```bash
# 1. Clear browser cache completely

# 2. Reload staging site

# 3. Test layers at multiple zoom levels:
#    - z=3-5:  Should show clean boundaries
#    - z=8-10: Should show clean boundaries
#    - z=14+:  Should show full detail

# 4. Compare to production (if still using CartoDB)
```

## Performance & Cost

### Batch Job Sizing

Default: 50 files per job

```bash
# Process more files per job (faster, but less resume granularity)
export FILES_PER_JOB=100

# Process fewer files per job (more granular, easier to retry failures)
export FILES_PER_JOB=25
```

### Spot Instance Savings

AWS Batch uses spot instances by default (60-90% savings):

```bash
# Disable spot (not recommended)
export USE_SPOT=false
```

### Estimated Costs

| Files | Size/File | Total Size | Spot Cost | On-Demand Cost |
|-------|-----------|------------|-----------|----------------|
| 10    | 100 MB    | 1 GB       | ~$0.10    | ~$0.50         |
| 100   | 100 MB    | 10 GB      | ~$1.00    | ~$5.00         |
| 1000  | 100 MB    | 100 GB     | ~$10.00   | ~$50.00        |

**Note:** Actual costs depend on file size, compression, and processing time.

## Advanced Usage

### Dry Run

Preview what would happen without executing:

```bash
export DRY_RUN=true
python manage_cog_conversion.py regenerate \
  --keys-file=my_keys.txt \
  --overview-resampling=NEAREST \
  --overwrite
```

### Custom Compression

Override compression method:

```bash
export COMPRESSION=ZSTD  # Options: LZW, DEFLATE, ZSTD

python manage_cog_conversion.py regenerate \
  --keys-file=my_keys.txt \
  --overwrite
```

### Custom AWS Batch Settings

```bash
# Increase concurrent processing
export MAX_VCPUS=32
export JOB_VCPUS=4
export JOB_MEMORY=8192

# Process more files per job
export FILES_PER_JOB=100
```

## Integration with Database

### Find Categorical Layers

```python
# Using generate_categorical_tiff_list.py
python generate_categorical_tiff_list.py --output=keys.txt
```

### Find Layers by Other Criteria

Write custom query script:

```python
import psycopg2

conn = psycopg2.connect(...)
cursor = conn.cursor()

# Example: Find layers by slug pattern
cursor.execute("""
    SELECT layer_config
    FROM layers
    WHERE slug LIKE 'land_cover%'
""")

# Extract tables and generate keys
# ... similar to generate_categorical_tiff_list.py
```

## See Also

- [CATEGORICAL_REGENERATION.md](CATEGORICAL_REGENERATION.md) - Specific guide for categorical layers
- [README.md](README.md) - General COG conversion overview
- [batch_handler.py](batch_container/batch_handler.py) - Core conversion logic
