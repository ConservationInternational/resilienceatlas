# CartoDB Vector Export Script

Bash script for extracting vector tables (with geometry columns) from an old CartoDB PostgreSQL/PostGIS database (PostgreSQL 9.6 on Ubuntu 12.04) and uploading them to S3.

**Designed for GDAL/OGR 1.11 compatibility.**

## Prerequisites

On the CartoDB server (Ubuntu 12.04):

1. **PostgreSQL client** (should already be installed):
   ```bash
   sudo apt-get install postgresql-client
   ```

2. **GDAL/OGR 1.11** (should already be installed, or):
   ```bash
   sudo apt-get install gdal-bin
   ```

3. **AWS CLI** for S3 uploads:
   ```bash
   pip install awscli
   aws configure
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
export S3_PREFIX=cartodb-vectors/
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key

# 2. Make script executable
chmod +x export_vectors_bash.sh

# 3. Test OGR driver
./export_vectors_bash.sh test

# 4. List all vectors to CSV
./export_vectors_bash.sh list

# 5. Review the CSV, then export
./export_vectors_bash.sh export

# 6. Check status
./export_vectors_bash.sh status
```

## Commands

| Command | Description |
|---------|-------------|
| `list` | Discover all vector tables and write to CSV |
| `export` | Export vectors and upload to S3 |
| `status` | Show export progress |
| `retry` | Retry failed exports |
| `test` | Test OGR PostgreSQL driver |
| `single` | Export a single table: `./export_vectors_bash.sh single schema.table` |
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
| `S3_PREFIX` | cartodb-vectors/ | S3 key prefix |
| `AWS_DEFAULT_REGION` | us-east-1 | AWS region |

### Export Options
| Variable | Default | Description |
|----------|---------|-------------|
| `EXPORT_FORMAT` | geojson | Output format: `geojson`, `shapefile`, `gpkg` |
| `OUTPUT_DIR` | ./vector_exports | Local export directory |
| `CLEANUP_LOCAL` | true | Delete local files after S3 upload to save disk space |

## Export Formats

### GeoJSON (default, recommended)
```bash
EXPORT_FORMAT=geojson ./export_vectors_bash.sh export
```
- Most portable format
- Single file per table
- No size limits
- Easy to read/process

### Shapefile
```bash
EXPORT_FORMAT=shapefile ./export_vectors_bash.sh export
```
- Multiple files per table (.shp, .shx, .dbf, .prj)
- 2GB file size limit
- 10-character field name limit
- Wide software compatibility

### GeoPackage (introduced in GDAL 1.11)
```bash
EXPORT_FORMAT=gpkg ./export_vectors_bash.sh export
```
- Single SQLite file
- Introduced in GDAL 1.11 - should work but may have limitations
- Requires SQLite3 to be compiled into GDAL
- Check availability: `ogrinfo --formats | grep -i gpkg`

## Output Structure

```
vector_exports/
├── vectors.csv              # List of all discovered vectors
├── exported_vectors.txt     # Successfully exported vector IDs
├── failed_vectors.txt       # Failed exports with reason
├── export.log               # Detailed log file
├── public_my_table.geojson      # Exported GeoJSON files
├── public_my_table.shp          # Shapefile (if using shapefile format)
├── public_my_table.shx
├── public_my_table.dbf
├── public_my_table.prj
└── schema_table_chunks/         # Chunks for large tables
```

S3 structure:
```
s3://your-bucket/cartodb-vectors/
├── public/
│   ├── my_table.geojson
│   └── large_table_chunks/
│       ├── chunk_0001.geojson
│       └── chunk_0002.geojson
└── other_schema/
    └── another_table.geojson
```

## Export Methods

The script tries multiple export methods in order of preference:

1. **OGR ogr2ogr** - Most efficient
   - Uses PostgreSQL driver
   - Handles all geometry types
   - Preserves attributes and projection

2. **SQL ST_AsGeoJSON** - Fallback for GeoJSON
   - Direct PostgreSQL export
   - Builds FeatureCollection in SQL
   - Good for smaller tables

3. **SQL WKT** - Last resort fallback
   - Exports as CSV with WKT geometry column
   - Can be converted to other formats later

4. **Chunked export** - For large tables (>100k rows)
   - Exports in batches of 10,000 rows
   - Prevents memory issues
   - Creates multiple files

## Resuming Interrupted Exports

The script tracks progress in text files:
- `exported_vectors.txt` - Successfully exported vectors
- `failed_vectors.txt` - Failed exports with reason

Simply run `./export_vectors_bash.sh export` again to resume.

To retry failed exports:
```bash
./export_vectors_bash.sh retry
```

## OGR 1.11 Notes

The script is designed for OGR 1.11 compatibility:

1. **Connection string format**: Uses quoted parameters
   ```
   PG:host=xxx dbname='xxx' user='xxx' password='xxx'
   ```

2. **SQL queries**: Uses `-sql` parameter for table selection

3. **Driver check**: Run `./export_vectors_bash.sh test` to verify drivers

### Check available drivers
```bash
ogrinfo --formats | grep -i "PostgreSQL\|GeoJSON\|Shapefile"
```

## Troubleshooting

### Check OGR version and drivers
```bash
ogr2ogr --version
ogrinfo --formats | grep -iE "postgres|geojson|shape"
```

### Test database connection
```bash
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
  -c "SELECT COUNT(*) FROM geometry_columns"
```

### View export logs
```bash
tail -f ./vector_exports/export.log
```

### Export a single table for testing
```bash
./export_vectors_bash.sh single public.my_table
```

### Memory issues with large tables
Large tables (>100k rows) are automatically exported in chunks. You can also:

```bash
# Export without S3 first
unset S3_BUCKET
./export_vectors_bash.sh export

# Then sync to S3
aws s3 sync ./vector_exports/ s3://your-bucket/cartodb-vectors/
```

### Encoding issues
If you see encoding errors:
```bash
export PGCLIENTENCODING=UTF8
./export_vectors_bash.sh export
```

### Empty GeoJSON output
If tables export as empty, check:
1. Table has geometry column: `SELECT * FROM geometry_columns WHERE f_table_name = 'tablename'`
2. Table has data: `SELECT COUNT(*) FROM schema.tablename`
3. Geometry is not all NULL: `SELECT COUNT(*) FROM schema.tablename WHERE geom_col IS NOT NULL`