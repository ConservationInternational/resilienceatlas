# CartoDB Raster Export Script

Bash script for extracting rasters from an old CartoDB PostgreSQL/PostGIS database (PostgreSQL 9.6 on Ubuntu 12.04) and uploading them to S3.

**Designed for GDAL 1.11 compatibility.**

## Prerequisites

On the CartoDB server (Ubuntu 12.04):

1. **PostgreSQL client** (should already be installed):
   ```bash
   sudo apt-get install postgresql-client
   ```

2. **GDAL 1.11** (should already be installed, or):
   ```bash
   sudo apt-get install gdal-bin
   ```

3. **AWS CLI or s3cmd** for S3 uploads:
   ```bash
   # Option 1: s3cmd (easier on old Ubuntu)
   sudo apt-get install s3cmd
   s3cmd --configure
   
   # Option 2: AWS CLI (may need pip)
   pip install awscli
   aws configure
   ```

4. **xxd** for hex decoding (usually pre-installed, part of vim):
   ```bash
   sudo apt-get install vim-common
   ```

## Quick Start

```bash
# 1. Set environment variables
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=cartodb_user_db
export DB_USER=postgres
export DB_PASSWORD=your_password

export S3_BUCKET=your-bucket-name
export S3_PREFIX=cartodb-rasters/
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key

# 2. Make script executable
chmod +x export_rasters_bash.sh

# 3. Test GDAL driver
./export_rasters_bash.sh test

# 4. List all rasters to CSV
./export_rasters_bash.sh list

# 5. Review the CSV, then export
./export_rasters_bash.sh export

# 6. Check status
./export_rasters_bash.sh status
```

## Commands

| Command | Description |
|---------|-------------|
| `list` | Discover all rasters and write to CSV |
| `export` | Export rasters and upload to S3 |
| `status` | Show export progress |
| `retry` | Retry failed exports |
| `test` | Test GDAL PostGIS Raster driver |
| `help` | Show usage information |

## Environment Variables

### Database Connection
| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | localhost | PostgreSQL host |
| `DB_PORT` | 5432 | PostgreSQL port |
| `DB_NAME` | cartodb | Database name |
| `DB_USER` | postgres | Database user |
| `DB_PASSWORD` | (empty) | Database password |

### S3 Upload
| Variable | Default | Description |
|----------|---------|-------------|
| `S3_BUCKET` | (required) | S3 bucket name |
| `S3_PREFIX` | cartodb-rasters/ | S3 key prefix |
| `AWS_DEFAULT_REGION` | us-east-1 | AWS region |

### Output
| Variable | Default | Description |
|----------|---------|-------------|
| `OUTPUT_DIR` | ./raster_exports | Local export directory |

## Output Structure

```
raster_exports/
├── rasters.csv              # List of all discovered rasters
├── exported_rasters.txt     # Successfully exported raster IDs
├── failed_rasters.txt       # Failed exports with reason
├── export.log               # Detailed log file
├── public_my_raster_rast.tif    # Exported GeoTIFFs
└── schema_table_column_tiles/   # Tiles for large rasters
```

S3 structure:
```
s3://your-bucket/cartodb-rasters/
├── public/
│   └── my_raster_table/
│       └── rast.tif
└── other_schema/
    └── another_table/
        ├── rast.tif
        └── rast_tiles/      # For large rasters exported as tiles
```

## Export Methods

The script tries multiple export methods in order of preference:

1. **GDAL gdal_translate** - Most efficient
   - Uses PostGIS Raster driver with `mode=2` (merges tiles)
   - Outputs compressed, tiled GeoTIFF
   - GDAL 1.11 compatible connection string format

2. **SQL ST_AsTIFF** - Fallback if GDAL fails
   - Direct PostgreSQL export via `psql`
   - Uses `ST_Union` to merge tiles before export
   - Hex-encoded output decoded with `xxd`

3. **Tile export** - For large rasters (>10 tiles)
   - Exports each tile as a separate GeoTIFF
   - Uploads entire directory to S3
   - Tiles can be merged later with `gdal_merge.py`

## Resuming Interrupted Exports

The script tracks progress in text files:
- `exported_rasters.txt` - Successfully exported rasters
- `failed_rasters.txt` - Failed exports with reason

Simply run `./export_rasters_bash.sh export` again to resume. Already exported rasters (in status file or S3) will be skipped.

To retry failed exports:
```bash
./export_rasters_bash.sh retry
```

## GDAL 1.11 Notes

The script is specifically designed for GDAL 1.11 compatibility:

1. **Connection string format**: Uses quoted parameters
   ```
   PG:host=xxx dbname='xxx' schema='xxx' table='xxx' column='xxx' mode=2
   ```

2. **Compression options**: Uses LZW (widely supported)

3. **BIGTIFF**: Uses `IF_SAFER` mode for automatic large file handling

4. **Driver check**: Run `./export_rasters_bash.sh test` to verify the PostGIS Raster driver is available

### If GDAL export fails

Common issues with GDAL 1.11:

1. **Driver not available**: Check with `gdalinfo --formats | grep -i postgis`
   - May need to rebuild GDAL with PostgreSQL support

2. **Password special characters**: If password contains special chars, the SQL fallback method will be used

3. **Corrupt rasters**: Some rasters may be malformed - the SQL method often handles these better

## Troubleshooting

### Check GDAL version and drivers
```bash
gdal_translate --version
gdalinfo --formats | grep -i postgis
```

### Test database connection
```bash
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT COUNT(*) FROM raster_columns"
```

### View export logs
```bash
tail -f ./raster_exports/export.log
```

### Check failed exports
```bash
cat ./raster_exports/failed_rasters.txt
```

### Force re-export a specific raster
```bash
# Remove from status file
sed -i '/schema.table.column/d' ./raster_exports/exported_rasters.txt

# Run export again
./export_rasters_bash.sh export
```

### Memory issues with large rasters
For very large rasters, the tile export method is used automatically. You can also export to local disk first, then use `aws s3 sync`:

```bash
# Export without S3 (unset S3_BUCKET)
unset S3_BUCKET
./export_rasters_bash.sh export

# Then sync to S3
aws s3 sync ./raster_exports/ s3://your-bucket/cartodb-rasters/
```
