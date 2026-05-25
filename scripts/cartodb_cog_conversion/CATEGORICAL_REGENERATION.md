# Categorical COG Regeneration Scripts

## Problem

Categorical raster layers (land cover, zones, etc.) show noise/color fringing when zoomed out because the COGs were created with `OVERVIEW_RESAMPLING=AVERAGE`, which interpolates between discrete pixel values.

## Solution

Regenerate categorical COGs with `OVERVIEW_RESAMPLING=NEAREST` to preserve discrete values in pyramid overviews.

## Scripts

### 1. generate_categorical_tiff_list.py

Queries the database to find all categorical layers and generates the list of S3 keys for their source TIFF files.

**Usage:**

```bash
# Set database connection (if not using defaults)
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=resilienceatlas_development
export DB_USER=postgres
export DB_PASSWORD=yourpassword

# Generate comma-separated list (for TIFF_KEYS env var)
python generate_categorical_tiff_list.py

# Generate one per line
python generate_categorical_tiff_list.py --format=lines

# Save to file
python generate_categorical_tiff_list.py --format=lines --output=categorical_tiffs.txt

# Filter by table name
python generate_categorical_tiff_list.py --filter=land_cover
```

**Output example:**
```
cartodb_exports/rasters/land_cover_2015.tif,cartodb_exports/rasters/land_cover_degradation.tif,...
```

### 2. regenerate_categorical_cogs.py

Convenience script that combines database query + batch conversion.

**Usage:**

```bash
# Set S3 bucket
export S3_BUCKET=resilienceatlas
export AWS_PROFILE=resilienceatlas  # if needed

# Dry run (preview what would happen)
python regenerate_categorical_cogs.py --dry-run

# Regenerate all categorical COGs
python regenerate_categorical_cogs.py

# Test with one file first
python regenerate_categorical_cogs.py --limit=1

# Only regenerate specific layers
python regenerate_categorical_cogs.py --filter=land_cover
```

**What it does:**
1. Queries database for layers with `analysis_type='categorical'`
2. Extracts table names from layer configs
3. Converts to S3 TIFF keys
4. Runs batch_handler.py with `OVERVIEW_RESAMPLING=NEAREST`

### 3. Manual Approach (batch_handler.py directly)

If you already have a list of specific files:

```bash
export S3_BUCKET=resilienceatlas
export OVERVIEW_RESAMPLING=NEAREST
export OVERWRITE=true
export TIFF_KEYS="cartodb_exports/rasters/land_cover_2015.tif,cartodb_exports/rasters/land_cover_degradation.tif"

python batch_container/batch_handler.py
```

## Prerequisites

```bash
# Install Python dependencies
pip install psycopg2-binary boto3

# Ensure AWS credentials are configured
aws configure --profile resilienceatlas
# or
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

## Step-by-Step Guide

### Quick Test (Single File)

```bash
# 1. Set environment
export S3_BUCKET=resilienceatlas
export AWS_PROFILE=resilienceatlas

# 2. Test with one file
python regenerate_categorical_cogs.py --limit=1

# 3. Verify on staging
# - Clear browser cache
# - Load the layer at zoom level 5-8
# - Check for clean boundaries (no noise)
```

### Full Regeneration

```bash
# 1. Dry run first
python regenerate_categorical_cogs.py --dry-run

# 2. Review the file list

# 3. Run for real
python regenerate_categorical_cogs.py

# 4. Wait for completion (monitor logs)

# 5. Verify on staging
# - Test multiple categorical layers
# - Check various zoom levels (3-14)
# - Compare to production if available
```

### Filter Specific Layers

```bash
# Only land cover layers
python regenerate_categorical_cogs.py --filter=land_cover

# Only degradation layers  
python regenerate_categorical_cogs.py --filter=degradation

# Test filter first with dry-run
python regenerate_categorical_cogs.py --filter=land_cover --dry-run
```

## Database Query

The scripts use this query to find categorical layers:

```sql
SELECT 
    id,
    slug,
    layer_config
FROM layers 
WHERE layer_provider = 'cog' 
  AND analysis_type = 'categorical'
  AND layer_config IS NOT NULL
ORDER BY id;
```

Then extract table names from:
- `layer_config.cartodb_migration.tables` (keys)
- `layer_config.cartodb_migration.raster_tables` (array)
- `layer_config.cartodb_migration.source_sql` (parse FROM/JOIN clauses)

## Verification

After regenerating COGs:

### 1. Check COG Metadata

```bash
# Download a regenerated COG
aws s3 cp s3://resilienceatlas/cogs/land_cover_2015.tif ./test.tif

# Check for overviews
gdalinfo test.tif | grep -A 5 "Overviews"
```

### 2. Visual Test

1. Clear browser cache completely
2. Load staging site
3. Enable a categorical layer (e.g., Land cover)
4. Zoom to level 5-8 (zoomed out view)
5. Look for:
   - ✅ Clean class boundaries
   - ✅ Solid colors (no speckles)
   - ❌ NO random noise/fringing

### 3. Compare Zoom Levels

- **Zoomed in (z=12-14):** Should look identical before/after
- **Zoomed out (z=3-8):** Should look MUCH cleaner after fix

## Troubleshooting

### "No categorical tables found"

Check database connection:
```bash
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM layers WHERE analysis_type='categorical';"
```

### "S3_BUCKET not set"

```bash
export S3_BUCKET=resilienceatlas
```

### AWS Permission Errors

Ensure your AWS credentials have:
- `s3:GetObject` on source prefix
- `s3:PutObject` on COG prefix

### Batch Handler Fails

Check the environment variables are passed:
```bash
python -c "import os; print('OVERVIEW_RESAMPLING:', os.environ.get('OVERVIEW_RESAMPLING'))"
```

## Performance

- **Single file:** ~30-60 seconds
- **Batch of 50 files:** ~30-60 minutes (depends on file sizes)
- **All categorical layers:** Estimate based on file count

## Rollback

If regenerated COGs cause issues:

```bash
# If you backed up the originals
aws s3 sync s3://resilienceatlas/cogs-backup/ s3://resilienceatlas/cogs/

# Or regenerate with AVERAGE again (not recommended)
export OVERVIEW_RESAMPLING=AVERAGE
export OVERWRITE=true
python batch_container/batch_handler.py
```

## Next Steps After Regeneration

1. ✅ Verify visual quality on staging
2. ✅ Test layer analysis functionality
3. ✅ Check that continuous layers still look smooth
4. Deploy to production (same process)
5. Update documentation with lessons learned
