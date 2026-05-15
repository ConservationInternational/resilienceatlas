# CartoDB Table Export

Exports non-spatial tables from an old CartoDB PostgreSQL database to gzipped CSV files and uploads to S3.

## Overview

This script exports tables that are **NOT** captured by the vector or raster export scripts - specifically, regular data tables without any spatial columns (geometry, geography, or raster).

## Compatibility

Designed for the legacy CartoDB environment:
- **Ubuntu 12.04** (Precise)
- **PostgreSQL 9.6**
- **Pure bash** (no Python 3 dependency)

## Prerequisites

- PostgreSQL client (`psql`)
- `gzip` (standard on most systems)
- AWS CLI (`aws`) for S3 uploads

```bash
# Check prerequisites
which psql gzip aws
```

## Quick Start

```bash
# 1. Set database connection
export DB_HOST=your-cartodb-server
export DB_PORT=5432
export DB_NAME=cartodb_user_db
export DB_USER=postgres
export DB_PASSWORD=your_password

# 2. Set S3 destination
export S3_BUCKET=my-backup-bucket
export S3_PREFIX=cartodb-tables/

# 3. List all non-spatial tables
./export_tables_bash.sh list

# 4. Export all tables
./export_tables_bash.sh export

# 5. Check progress
./export_tables_bash.sh status
```

## Commands

### `list` - Discover Tables

Scans the database for all tables that:
- Are in user schemas (not system schemas)
- Do NOT have geometry columns
- Do NOT have geography columns
- Do NOT have raster columns

```bash
./export_tables_bash.sh list
```

Output: `table_exports/tables.csv` with columns:
- `schema` - PostgreSQL schema
- `table` - Table name
- `row_count` - Approximate row count
- `size_bytes` - Table size in bytes
- `column_count` - Number of columns

### `export` - Export Tables

Exports all discovered tables to gzipped CSV files and uploads to S3.

```bash
./export_tables_bash.sh export
```

Features:
- Skips already-exported tables (checks status file and optionally S3)
- Skips empty tables
- Large tables (>100k rows) are exported in chunks then merged
- Cleans up local files after successful S3 upload

### `status` - Show Progress

```bash
./export_tables_bash.sh status
```

Example output:
```
==========================================
  Table Export Status
==========================================
  Total tables:     42
  Exported:         35
  Failed:           2
  Remaining:        5
==========================================
```

### `single` - Export One Table

```bash
./export_tables_bash.sh single public.my_table
```

### `retry` - Retry Failed

```bash
./export_tables_bash.sh retry
```

## Configuration

### Database Connection

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `cartodb` | Database name |
| `DB_USER` | `postgres` | Database user |
| `DB_PASSWORD` | (empty) | Database password |

### S3 Upload

| Variable | Default | Description |
|----------|---------|-------------|
| `S3_BUCKET` | (none) | S3 bucket name |
| `S3_PREFIX` | `cartodb-tables/` | S3 key prefix |
| `AWS_DEFAULT_REGION` | `us-east-1` | AWS region |

### Export Options

| Variable | Default | Description |
|----------|---------|-------------|
| `OUTPUT_DIR` | `./table_exports` | Local output directory |
| `CLEANUP_LOCAL` | `true` | Delete local files after S3 upload |
| `SKIP_S3_CHECK` | `false` | Skip checking S3 for existing files |
| `CHUNK_SIZE` | `100000` | Rows per chunk for large tables |

## Output Structure

### Local Files

```
table_exports/
├── tables.csv               # List of all discovered tables
├── exported_tables.txt      # Successfully exported table IDs
├── failed_tables.txt        # Failed exports with reason
├── export.log               # Detailed log file
└── schema_table.csv.gz      # Exported gzipped CSV files
```

### S3 Structure

```
s3://your-bucket/cartodb-tables/
├── public_users.csv.gz
├── public_config.csv.gz
├── myschema_settings.csv.gz
└── ...
```

## How It Excludes Spatial Tables

The script queries PostgreSQL metadata views to find tables without spatial columns:

```sql
-- Excluded: tables in geometry_columns
SELECT f_table_schema, f_table_name FROM geometry_columns

-- Excluded: tables in geography_columns  
SELECT f_table_schema, f_table_name FROM geography_columns

-- Excluded: tables in raster_columns
SELECT r_table_schema, r_table_name FROM raster_columns

-- Exported: all user tables NOT in the above
```

This ensures that tables already handled by:
- `export_rasters_bash.sh` (raster tables)
- `export_vectors_bash.sh` (vector/geometry tables)

...are automatically excluded.

## CSV Format

Output files are:
- **Format**: RFC 4180 compliant CSV
- **Encoding**: UTF-8
- **Header**: First row contains column names
- **Compression**: gzip
- **Null handling**: Empty string for NULL values

Example:
```csv
id,name,value,created_at
1,"Test Item",42.5,2024-01-15 10:30:00
2,"Another","",2024-01-16 11:45:00
```

## Large Table Handling

Tables with more than `CHUNK_SIZE` rows (default: 100,000) are:
1. Exported in chunks using `LIMIT/OFFSET`
2. Each chunk is gzipped separately
3. Chunks are merged into a single file
4. Chunk files are cleaned up

This prevents memory issues on the constrained Ubuntu 12.04 system.

## Resume & Skip Logic

The script tracks export progress:

1. **Status file** (`exported_tables.txt`): Lists successfully exported tables
2. **S3 check** (optional): Verifies file exists in S3

On subsequent runs, already-exported tables are skipped. To re-export:
```bash
# Remove from status file
sed -i '/schema.table/d' table_exports/exported_tables.txt

# Or clear all
> table_exports/exported_tables.txt
```

## Troubleshooting

### View Export Log

```bash
tail -f table_exports/export.log
```

### Test Database Connection

```bash
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1"
```

### Check Table Exclusion

Verify a table is correctly classified:
```bash
# Check if table has geometry column
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT * FROM geometry_columns WHERE f_table_name = 'my_table'"

# Check if table has raster column  
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c \
  "SELECT * FROM raster_columns WHERE r_table_name = 'my_table'"
```

### Manual Export Test

```bash
# Export single table to test
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d $DB_NAME \
  -c "\COPY (SELECT * FROM public.my_table) TO STDOUT WITH CSV HEADER" | gzip > test.csv.gz
```

## See Also

- [export_rasters_bash.sh](../cartodb_raster_export/) - Export raster tables
- [export_vectors_bash.sh](../cartodb_vector_export/) - Export vector/geometry tables
- [manage_cog_conversion.sh](../cartodb_cog_conversion/) - Convert rasters to COG format
