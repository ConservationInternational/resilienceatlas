# CartoDB → PostgreSQL Migration

End-to-end guide for migrating CartoDB non-spatial tables into the Resilience Atlas
PostgreSQL database and updating the layer rows that previously referenced them.

The process has two halves:

| Phase | Where it runs | Tool |
|-------|--------------|------|
| **Export** | CartoDB server (Ubuntu 12.04) | `export_tables_bash.sh` |
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

Run on the **CartoDB server**.  See [README.md](README.md) for full details.

```bash
# On the CartoDB server
export DB_HOST=localhost
export DB_NAME=cartodb_user_db
export DB_USER=postgres
export DB_PASSWORD=...
export S3_BUCKET=my-backup-bucket
export S3_PREFIX=cartodb-tables/

# List all non-spatial tables that will be exported
./export_tables_bash.sh list

# Export all tables and upload to S3
./export_tables_bash.sh export

# Check progress
./export_tables_bash.sh status
```

### What gets uploaded to S3

```
s3://my-backup-bucket/cartodb-tables/
├── tables.csv                         ← manifest (schema, table, row_count, …)
├── public_sbtn_thresholds.csv.gz      ← {schema}_{table}.csv.gz
├── public_ecoregion_data.csv.gz
└── …
```

Only **non-spatial** tables are exported here (no geometry / raster columns).
Spatial vector tables are handled by a separate `export_vectors_bash.sh` and are
served via the Martin tile server after migration.

---

## Phase 2 — Import into PostgreSQL

Run inside the **Rails application** (Docker or direct).

### Prerequisites

- AWS CLI with credentials (for S3 source) **or** the exported CSV.GZ files
  mounted/copied to a local path.
- PostgreSQL client (`psql`) accessible inside the container.

### Available tasks

| Task | Purpose |
|------|---------|
| `rake cartodb:import_tables` | Download CSV.GZ files and load each as a PostgreSQL table |
| `rake cartodb:update_layer_references` | Update formerly CartoDB `Layer` rows to reference the imported tables |
| `rake cartodb:migrate_tables` | Run both tasks in sequence |
| `rake cartodb:status` | Show current migration status of all flagged layers |

---

### `rake cartodb:import_tables`

Before downloading anything, the task queries the database for all layers flagged by
the migration (`layer_provider IS NULL`, `published = false`, `query` present) and
parses their SQL to collect every referenced table name.  Only files whose table name
appears in that list are downloaded and imported — unreferenced files on S3 are
silently skipped.  Any table that is referenced by a layer but has **no matching file
on S3** is printed as a warning to aid debugging.

The task aborts with an error if no flagged layers exist in the database, or if no
table names can be parsed from their queries.

Column types are inferred automatically from a 1 000-row sample
(`bigint`, `double precision`, `boolean`, or `text`).

**Environment variables**

| Variable | Default | Description |
|----------|---------|-------------|
| `CARTODB_S3_BUCKET` | _(none)_ | S3 bucket containing the exports.  Required when using S3. |
| `CARTODB_S3_PREFIX` | `cartodb-tables/` | S3 key prefix |
| `CARTODB_EXPORT_DIR` | `/data/cartodb-tables` | Local directory with `.csv.gz` files (used when `CARTODB_S3_BUCKET` is not set) |
| `CARTODB_IMPORT_SCHEMA` | `ra_vector` | Target PostgreSQL schema |
| `FORCE` | _(unset)_ | Set to `1` to overwrite existing tables without prompting |

**From S3 (typical production use)**

```bash
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:import_tables \
  CARTODB_S3_BUCKET=my-backup-bucket \
  CARTODB_S3_PREFIX=cartodb-tables/
```

**From a local directory**

```bash
# Mount the directory containing the .csv.gz files, then:
docker compose -f docker-compose.dev.yml run --rm \
  -v /path/to/cartodb-tables:/data/cartodb-tables:ro \
  backend \
  rake cartodb:import_tables CARTODB_EXPORT_DIR=/data/cartodb-tables
```

**Import a single table**

The task only imports files that are needed by a layer.  To force-import a specific
file that is not yet referenced by any layer, place only that file (and the
`tables.csv` manifest) in a local export directory and use `CARTODB_EXPORT_DIR`
while pointing at a database that has no flagged layers (fallback mode).

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
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:update_layer_references
```

---

### `rake cartodb:migrate_tables` (combined)

Runs `import_tables` then `update_layer_references` in a single command.  Accepts
all environment variables from both sub-tasks.

```bash
docker compose -f docker-compose.dev.yml run --rm backend \
  rake cartodb:migrate_tables \
  CARTODB_S3_BUCKET=my-backup-bucket \
  FORCE=1
```

---

### `rake cartodb:status`

Re-checks table availability and prints a per-layer report without making any
changes.  Use it to monitor progress or verify a completed migration.

```bash
docker compose -f docker-compose.dev.yml run --rm backend rake cartodb:status
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

CartoDB spatial tables (geometry columns) are **not** exported by
`export_tables_bash.sh` — they are handled by the separate `export_vectors_bash.sh`
script and imported into PostGIS, then served via Martin.  If a layer's
`cartodb_migration.tables` shows a spatial table as `"missing"`, it needs to be
imported via the vector export pipeline and registered in Martin.

---

## Troubleshooting

**`No export source found`**  
Set either `CARTODB_S3_BUCKET` (with valid AWS credentials) or
`CARTODB_EXPORT_DIR` pointing to a directory that exists and contains `.csv.gz` files.

**`aws CLI not found`**  
The backend Docker image must have `awscli` installed, or mount the CSV.GZ files
locally and use `CARTODB_EXPORT_DIR` instead.

**`Table already exists` prompt in CI / non-interactive**  
Pass `FORCE=1` to automatically overwrite without prompting.

**`No formerly CartoDB layers found`**  
The `update_layer_references` task only targets layers where
`layer_provider IS NULL AND published = false AND query IS NOT NULL`.
If all three conditions are not met (e.g. someone already set a provider),
run `rake cartodb:status` to inspect the current state.

**Re-running after adding more tables**  
Both tasks are safe to re-run.  `import_tables` will prompt before overwriting
(or skip with `FORCE=1`).  `update_layer_references` will update
`cartodb_migration.tables` with the latest availability.

**`WARNING: referenced by layers but NOT available on S3`**  
The task found table names in layer SQL queries that have no corresponding
`{schema}_{table}.csv.gz` file on S3.  This means either the table was spatial
(handled by the vector export pipeline) or it was never exported.  Check the
`export_tables_bash.sh status` output on the CartoDB server and re-run the export
if the file is missing.
