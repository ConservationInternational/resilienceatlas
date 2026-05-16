# CartoDB → PostgreSQL Migration

End-to-end guide for migrating CartoDB spatial vectors and non-spatial tables into the
Resilience Atlas PostgreSQL database and updating the layer rows that previously
referenced them.

The process has two halves:

| Phase | Where it runs | Tool |
|-------|--------------|------|
| **Export (vectors)** | CartoDB server (Ubuntu 12.04) | `export_vectors_bash.sh` |
| **Export (non-spatial)** | CartoDB server (Ubuntu 12.04) | `export_tables_bash.sh` |
| **Import + update** | Rails app server / Docker | `rake cartodb:*` tasks |

---

## Background

CartoDB layers stored their tile data and attribute tables inside a hosted CartoDB
account.  After the Leaflet → OpenLayers migration:

- `layer_provider = 'cartodb'` is no longer a valid provider.
- The `FlagCartodbLayersForReview` migration (20260515140000) **unpublished** all
  CartoDB layers and **cleared** their `layer_provider` so they do not block other
  admin saves.
- Each layer still has its original CartoDB SQL in the `query` column — that SQL
  references one or more CartoDB table names that need to be imported locally.

---

## Phase 1 — Export from CartoDB

Run on the **CartoDB server**.  Vectors and non-spatial tables are exported
by separate scripts into separate S3 prefixes.

### Step 1a — Export spatial vectors (primary)

See [`scripts/cartodb_vector_export/`](../cartodb_vector_export/) for full details.

```bash
# On the CartoDB server
export DB_HOST=localhost
export DB_NAME=cartodb_user_db
export DB_USER=postgres
export DB_PASSWORD=...
export S3_BUCKET=my-backup-bucket
export S3_PREFIX=cartodb_exports/vectors/   # prefix for .gpkg files

# List all vector tables that will be exported
./export_vectors_bash.sh list

# Export all vectors and upload to S3
./export_vectors_bash.sh export

# Check progress
./export_vectors_bash.sh status
```

**What gets uploaded:**

```
s3://my-backup-bucket/cartodb_exports/vectors/
├── public_yam_gh.gpkg       ← {schema}_{table}.gpkg
├── public_wri_sites.gpkg
└── …
```

### Step 1b — Export non-spatial tables (optional)

Only needed for tables without geometry that are referenced by CartoDB layer queries.
See [README.md](README.md) for full details.

```bash
export S3_PREFIX=cartodb_exports/non-spatial/   # separate prefix for .csv.gz files

# List all non-spatial tables
./export_tables_bash.sh list

# Export and upload to S3
./export_tables_bash.sh export

# Check progress
./export_tables_bash.sh status
```

**What gets uploaded:**

```
s3://my-backup-bucket/cartodb-tables/
├── tables.csv                         ← manifest (schema, table, row_count, …)
├── public_sbtn_thresholds.csv.gz      ← {schema}_{table}.csv.gz
└── …
```

---

## Phase 2 — Import into PostgreSQL

The rake tasks run inside the Rails application container and connect to whatever
database `DATABASE_URL` points to in the container's environment.  This means the
**same task code** is used for development, staging, and production — you just run
it in the right container with the right env file.

| Environment | How to run | Database |
|-------------|-----------|---------|
| **Local dev** | `docker compose -f docker-compose.dev.yml run --rm backend rake ...` | `db` container (`DATABASE_URL` from `backend/.env`) |
| **Staging** | `docker run` on the staging server with `--env-file .env.staging` | staging Postgres |
| **Production** | `docker run` on the production server with `--env-file .env` | production Postgres |

> **Do not** run `docker compose -f docker-compose.dev.yml` commands on the
> production or staging server — those commands use the dev `DATABASE_URL` which
> points at the local `db` container, not the server's Postgres instance.

### Prerequisites

- AWS CLI with credentials (for S3 source) **or** the exported CSV.GZ files
  mounted/copied to a local path.
- The backend Docker image built and available (`BACKEND_IMAGE` env var or the tag
  used in the relevant Compose / Swarm file).

### Available tasks

| Task | Purpose |
|------|---------|
| `rake cartodb:import_tables` | Import `.gpkg` vectors (via ogr2ogr) and `.csv.gz` non-spatial tables from S3 |
| `rake cartodb:update_layer_references` | Update formerly CartoDB `Layer` rows to reference the imported tables |
| `rake cartodb:migrate_tables` | Run both tasks in sequence |
| `rake cartodb:status` | Show current migration status of all flagged layers |

---

### `rake cartodb:import_tables`

Before downloading anything, the task queries the database for all layers flagged by
the migration (`layer_provider IS NULL`, `published = false`, `query` present) and
parses their SQL to collect every referenced table name.  It then lists both the
vectors prefix (for `.gpkg` files) and the tables prefix (for `.csv.gz` files) and
routes each referenced table to the correct import path:

- **Spatial vectors** (`.gpkg`) → downloaded and imported into PostGIS via `ogr2ogr`
- **Non-spatial tables** (`.csv.gz`) → downloaded and imported via PostgreSQL `COPY`

Vectors take priority: if a table name matches a `.gpkg` file it is always imported
that way, not as a CSV.  Any table referenced by a layer but absent from both prefixes
is printed as a warning.

The task aborts with an error if no flagged layers exist in the database, or if no
table names can be parsed from their queries.

Column types for non-spatial tables are inferred automatically from a 1 000-row
sample (`bigint`, `double precision`, `boolean`, or `text`).

**Environment variables**

| Variable | Default | Description |
|----------|---------|-------------|
| `CARTODB_S3_BUCKET` | _(none)_ | S3 bucket name only (no prefix).  Required when using S3. |
| `CARTODB_VECTORS_S3_PREFIX` | `cartodb_exports/vectors/` | S3 prefix for `.gpkg` vector files.  Must end with `/`. |
| `CARTODB_TABLES_S3_PREFIX` | `cartodb_exports/non-spatial/` | S3 prefix for `.csv.gz` non-spatial files.  Must end with `/`. |
| `CARTODB_EXPORT_DIR` | _(none)_ | Local directory with `.csv.gz` files (non-spatial only, used when `CARTODB_S3_BUCKET` is not set) |
| `CARTODB_IMPORT_SCHEMA` | `ra_vector` | Target PostgreSQL schema |
| `FORCE` | _(unset)_ | Set to `1` to overwrite tables that already exist in the database (default is to skip them) |

**Local development (imports into the dev `db` container)**

```bash
# From S3 — vectors at cartodb_exports/vectors/ and tables at cartodb_exports/non-spatial/ (defaults)
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:import_tables \
  CARTODB_S3_BUCKET=my-backup-bucket

# From S3 — explicit prefixes
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:import_tables \
  CARTODB_S3_BUCKET=my-backup-bucket \
  CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
  CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/

# Non-spatial tables from a local directory (vectors still require S3)
docker compose -f docker-compose.dev.yml run --rm \
  -v /path/to/cartodb-tables:/data/cartodb-tables:ro \
  backend \
  rake cartodb:import_tables CARTODB_EXPORT_DIR=/data/cartodb-tables
```

**Staging server (run on the staging host)**

```bash
source /opt/resilienceatlas-staging/.env.staging
docker run --rm -it \
  --network resilienceatlas-staging_staging-network \
  --env-file /opt/resilienceatlas-staging/.env.staging \
  -e RAILS_ENV=staging \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:import_tables \
    CARTODB_S3_BUCKET=my-backup-bucket \
    CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
    CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/
```

**Production server (run on the production host)**

```bash
source /opt/resilienceatlas/.env
docker run --rm -it \
  --network resilienceatlas-production_prod-network \
  --env-file /opt/resilienceatlas/.env \
  -e RAILS_ENV=production \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:import_tables \
    CARTODB_S3_BUCKET=my-backup-bucket \
    CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
    CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/
```

---

### `rake cartodb:update_layer_references`

Finds every `Layer` row that was flagged by the migration:

- `layer_provider IS NULL`
- `published = false`
- `query` is present (contains the original CartoDB SQL)

For each such layer the task:

1. **Parses** the `query` SQL to extract all `FROM` / `JOIN` table names.
2. **Checks** which of those tables now exist in the local database.
3. **Writes** a `cartodb_migration` block into `layer_config`:

   ```json
   {
     "cartodb_migration": {
       "status": "partial",
       "tables": {
         "sbtn_thresholds": "imported",
         "ecoregions2017": "missing"
       },
       "note": "Set layer_provider and update layer_config, then set published=true."
     }
   }
   ```

4. **Cleans** the `query` field — removes CartoDB-internal columns
   (`cartodb_id`, `the_geom_webmercator`, `the_geom`) so the SQL is valid
   against local tables once a provider is configured.

> All writes use `update_columns` to bypass model validations (necessary because
> `layer_provider = NULL` fails the presence validation).  Layers remain
> `published = false`.

**Environment variables**

| Variable | Default | Description |
|----------|---------|-------------|
| `CARTODB_IMPORT_SCHEMA` | `ra_vector` | Schema that was used for import (must match `import_tables`) |

```bash
# Dev
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:update_layer_references

# Staging / production — source the env file first so $BACKEND_IMAGE is set
source /opt/resilienceatlas/.env   # or .env.staging on the staging host
docker run --rm -it \
  --network resilienceatlas-production_prod-network \
  --env-file /opt/resilienceatlas/.env \
  -e RAILS_ENV=production \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:update_layer_references
```

---

### `rake cartodb:migrate_tables` (combined)

Runs `import_tables` then `update_layer_references` in a single command.  Accepts
all environment variables from both sub-tasks.

```bash
# Dev
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:migrate_tables \
  CARTODB_S3_BUCKET=my-backup-bucket FORCE=1

# Production
source /opt/resilienceatlas/.env
docker run --rm -it \
  --network resilienceatlas-production_prod-network \
  --env-file /opt/resilienceatlas/.env \
  -e RAILS_ENV=production \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:migrate_tables \
    CARTODB_S3_BUCKET=my-backup-bucket \
    CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
    CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/ \
    FORCE=1
```

---

### `rake cartodb:status`

Re-checks table availability and prints a per-layer report without making any
changes.  Use it to monitor progress or verify a completed migration.

```bash
# Dev
docker compose -f docker-compose.dev.yml run --rm backend rake cartodb:status

# Production
source /opt/resilienceatlas/.env
docker run --rm -it \
  --network resilienceatlas-production_prod-network \
  --env-file /opt/resilienceatlas/.env \
  -e RAILS_ENV=production \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:status
```

Example output:

```
=== CartoDB Migration Status (2026-05-15 14:30) ===

  Layers with provider=NULL             : 12
  of which unpublished with query (flagged): 12

  ✓ #42 sbtn-natural-land-exceedances
      ✓ public.sbtn_thresholds  (available)
      ✗ public.ecoregions2017   (missing)
  ✗ #43 sbtn-nitrogen-dep-baselines
      ✗ public.sbtn_thresholds  (missing)
      ✗ public.ecoregions2017   (missing)

  All tables imported : 0
  Partial             : 1
  No tables yet       : 11
```

---

## Phase 3 — Operator review in the admin UI

After running `migrate_tables`, each formerly CartoDB layer has:

- `published = false` — not visible to end users
- `layer_config` — contains the `cartodb_migration` status block
- `query` — CartoDB SQL with `cartodb_id` / `the_geom_webmercator` removed
- `layer_provider` — still `NULL`

The operator must configure each layer before republishing:

1. Open **Admin → Layers** and filter by `layer_provider IS NULL`.
2. For each layer, examine `cartodb_migration.tables` in `layer_config` to see
   which tables are available locally.
3. Choose the appropriate new provider and update `layer_config`:

   | Scenario | New provider | Notes |
   |----------|-------------|-------|
   | Geometry served by Martin tile server | `martin` | Point `layer_config` at the Martin endpoint |
   | Raster file in S3 / COG | `cog` | Set `layer_config.tiles` |
   | External WMS | `wms` | Set `layer_config.url` |

4. Remove (or replace) the `cartodb_migration` key in `layer_config` once done.
5. Set `published = true`.

### Spatial tables (`ecoregions2017`, etc.)

CartoDB spatial tables (geometry columns) are exported by `export_vectors_bash.sh`
as `.gpkg` GeoPackage files and are imported directly by `rake cartodb:import_tables`
into the `ra_vector` schema via `ogr2ogr`.  If a layer's `cartodb_migration.tables`
shows a spatial table as `"missing"`, check that the corresponding `.gpkg` file
exists on S3 at `CARTODB_VECTORS_S3_PREFIX` and that the table name matches the
`{schema}_{table}.gpkg` filename convention.

---

## Troubleshooting

**`No export source found`**  
Set either `CARTODB_S3_BUCKET` (with valid AWS credentials) or
`CARTODB_EXPORT_DIR` pointing to a directory that exists and contains `.csv.gz` files.

**`aws CLI not found`**  
The backend Docker image must have `awscli` installed, or mount the CSV.GZ files
locally and use `CARTODB_EXPORT_DIR` instead.

**Tables already in the database are skipped**  
`import_tables` silently skips any table that already exists in `CARTODB_IMPORT_SCHEMA`.
Pass `FORCE=1` to overwrite them instead.

**`No formerly CartoDB layers found`**  
The `update_layer_references` task only targets layers where
`layer_provider IS NULL AND published = false AND query IS NOT NULL`.
If all three conditions are not met (e.g. someone already set a provider),
run `rake cartodb:status` to inspect the current state.

**Re-running after adding more tables**  
Both tasks are safe to re-run.  `import_tables` skips tables that are already
present in the database; pass `FORCE=1` to overwrite them.
`update_layer_references` will update `cartodb_migration.tables` with the latest availability.

**`WARNING: referenced by layers but NOT found on S3`**  
The task found table names in layer SQL queries that have no corresponding file
(neither `.gpkg` at the vectors prefix nor `.csv.gz` at the tables prefix).  Either:
- The `.gpkg` export for that table is missing — check `export_vectors_bash.sh status`
  on the CartoDB server and re-run the export.
- The table is non-spatial and the `.csv.gz` export is missing — check
  `export_tables_bash.sh status` and re-run.
- The S3 prefix env vars (`CARTODB_VECTORS_S3_PREFIX`, `CARTODB_TABLES_S3_PREFIX`)
  do not match where the files were uploaded.
