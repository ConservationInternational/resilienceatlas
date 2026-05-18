# CartoDB → PostgreSQL Migration

End-to-end guide for migrating CartoDB spatial vectors and non-spatial tables into the
Resilience Atlas PostgreSQL database and updating the layer rows that previously
referenced them.

| Phase | Where it runs | Tool |
|-------|--------------|------|
| **Export (vectors)** | CartoDB server (Ubuntu 12.04) | `export_vectors_bash.sh` |
| **Export (non-spatial)** | CartoDB server (Ubuntu 12.04) | `export_tables_bash.sh` |
| **Import + configure** | Rails app server / Docker | `rake cartodb:migrate_tables` |
| **Repair** | Rails app server / Docker | `rake cartodb:fix_*` tasks |

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

The rake tasks automatically configure vector layers to use **Martin** (the PostGIS
tile server) and raster layers to use **TiTiler** (Cloud-Optimised GeoTIFF renderer).
After a successful run the vast majority of layers are published and visible without
manual intervention.

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

## Phase 2 — Import and auto-configure

The rake tasks run inside the Rails application container and connect to whatever
database `DATABASE_URL` points to in the container's environment.

| Environment | How to run | Database |
|-------------|-----------|---------|
| **Local dev** | `docker compose -f docker-compose.dev.yml run --rm backend rake ...` | `db` container |
| **Staging** | `docker run` on the staging server with `--env-file .env.staging` | staging Postgres |
| **Production** | `docker run` on the production server with `--env-file .env` | production Postgres |

> **Do not** run `docker compose -f docker-compose.dev.yml` commands on the production or
> staging server — those use the dev `DATABASE_URL` which points at the local `db`
> container, not the server's Postgres instance.

### `rake cartodb:migrate_tables` — primary command

Runs the full import, auto-configuration, and repair pipeline in a single command:

```
import_tables → update_layer_references → configure_cog_layers → configure_martin_layers
  → fix_cog_styles → fix_cog_sources → fix_cog_clip → fix_cog_interactivity
  → fix_martin_sources → fix_martin_styles → fix_martin_interactivity
```

| Step | What it does |
|------|-------------|
| `import_tables` | Downloads `.gpkg` vectors and `.csv.gz` tables from S3 and imports them into the `ra_vector` schema |
| `update_layer_references` | Parses each layer's CartoDB SQL, records which tables are now available, identifies raster vs vector layers, and strips CartoDB-internal columns from the query |
| `configure_cog_layers` | For raster-type layers: sets `layer_provider = "cog"`, builds `body.source` / `body.sources` pointing at the converted COGs on S3, translates CartoCSS stops to TiTiler colormap/rescale params, sets `interaction_config` for pixel value lookup, and publishes the layer |
| `configure_martin_layers` | For vector-type layers: sets `layer_provider = "martin"`, builds `body.source = "<table>"`, translates CartoCSS to OpenLayers `PathOptions`, sets `interaction_config` from table columns, and publishes the layer when all tables are present |
| `fix_cog_styles` | Re-translates CSS colormaps for **all** COG layers in the database (not just the ones configured in this run), ensuring correct `discrete`/`exact`/`linear` mode handling |
| `fix_cog_sources` | Rebuilds `body.sources` for **all** multi-table COG mosaic layers |
| `fix_cog_clip` | Extracts boundary polygons for raster layers that used CartoDB's `ST_CLIP` and stores a simplified GeoJSON in `body.clip_geometry`; the frontend passes this to TiTiler as the `feature` clip parameter |
| `fix_cog_interactivity` | Backfills `interaction_config` (TiTiler `/cog/point` pixel-value lookup) for COG layers that are missing it |
| `fix_martin_sources` | Strips any `ra_vector.` prefix from Martin `body.source` values |
| `fix_martin_styles` | Backfills missing PathOptions styles for Martin layers that have no `styles` object |
| `fix_martin_interactivity` | Builds `interaction_config` from PostGIS table columns for Martin layers; enables click popups that show feature attribute values directly from vector tile properties, with no HTTP round-trip |

The repair steps (5–11) are idempotent and cover all layers already in the database, not
just the ones configured in the current run.  Re-running `migrate_tables` at any time
is safe and leaves the database in a fully consistent state.

**Local dev**

```bash
docker compose -f docker-compose.dev.yml run --rm backend \
  bundle exec rake cartodb:migrate_tables \
  CARTODB_S3_BUCKET=resilienceatlas \
  CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
  CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/
```

**Staging server**

```bash
source /opt/resilienceatlas-staging/.env.staging
docker run --rm -it \
  --network resilienceatlas-staging_staging-network \
  --env-file /opt/resilienceatlas-staging/.env.staging \
  -e RAILS_ENV=staging \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:migrate_tables \
    CARTODB_S3_BUCKET=resilienceatlas \
    CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
    CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/
```

**Production server**

```bash
source /opt/resilienceatlas/.env
docker run --rm -it \
  --network resilienceatlas-production_prod-network \
  --env-file /opt/resilienceatlas/.env \
  -e RAILS_ENV=production \
  "$BACKEND_IMAGE" \
  bundle exec rake cartodb:migrate_tables \
    CARTODB_S3_BUCKET=resilienceatlas \
    CARTODB_VECTORS_S3_PREFIX=cartodb_exports/vectors/ \
    CARTODB_TABLES_S3_PREFIX=cartodb_exports/non-spatial/
```

**Environment variables accepted by `migrate_tables`**

| Variable | Default | Description |
|----------|---------|-------------|
| `CARTODB_S3_BUCKET` | _(required)_ | S3 bucket name |
| `CARTODB_VECTORS_S3_PREFIX` | `cartodb_exports/vectors/` | S3 prefix for `.gpkg` vector files |
| `CARTODB_TABLES_S3_PREFIX` | `cartodb_exports/non-spatial/` | S3 prefix for `.csv.gz` non-spatial files |
| `CARTODB_IMPORT_SCHEMA` | `ra_vector` | Target PostgreSQL schema |
| `S3_BUCKET` | `resilienceatlas` | S3 bucket for the converted COG `.tif` files |
| `COG_PREFIX` | `cogs/` | S3 key prefix for COG files |
| `FORCE` | _(unset)_ | Set to `1` to re-import tables that already exist |
| `DRY_RUN` | _(unset)_ | Set to `1` on any sub-task to preview without saving |

---

## Repair tasks (standalone)

The `fix_*` tasks are included in `migrate_tables` and do not need to be run
separately as part of a normal migration.  They are available as standalone commands
for targeted repairs — for example, if you need to re-translate colormaps without
re-importing tables, or if you want to preview what would change before committing.

```bash
# Re-translate colormaps for all COG layers
bundle exec rake cartodb:fix_cog_styles DRY_RUN=1
bundle exec rake cartodb:fix_cog_styles

# Rebuild body.sources for multi-table COG mosaic layers
bundle exec rake cartodb:fix_cog_sources DRY_RUN=1
bundle exec rake cartodb:fix_cog_sources

# Store clip boundary polygons for ST_CLIP raster layers
bundle exec rake cartodb:fix_cog_clip DRY_RUN=1
bundle exec rake cartodb:fix_cog_clip

# Set TiTiler point-query interaction_config for COG layers
bundle exec rake cartodb:fix_cog_interactivity DRY_RUN=1
bundle exec rake cartodb:fix_cog_interactivity

# Strip ra_vector. prefix from Martin source IDs
bundle exec rake cartodb:fix_martin_sources DRY_RUN=1
bundle exec rake cartodb:fix_martin_sources

# Backfill missing PathOptions styles for Martin layers
bundle exec rake cartodb:fix_martin_styles DRY_RUN=1
bundle exec rake cartodb:fix_martin_styles

# Build click-popup field list from PostGIS table columns for Martin layers
bundle exec rake cartodb:fix_martin_interactivity DRY_RUN=1
bundle exec rake cartodb:fix_martin_interactivity FORCE=1   # overwrite existing configs
bundle exec rake cartodb:fix_martin_interactivity
```

All tasks are idempotent — layers that are already correct are skipped.

---

## Phase 3 — Post-import one-time setup

These tasks only need to be run **once** after the initial bulk import and are safe
to skip on subsequent re-runs (they detect and skip work that is already done).

### `rake cartodb:create_spatial_indices`

Creates GiST spatial indices on all geometry columns in the `ra_vector` schema.
Martin requires these indices to compute tile bounds at startup — without them it
times out and drops sources.  `import_tables` creates indices automatically for new
imports; this task backfills any tables that were imported before that step existed.

```bash
bundle exec rake cartodb:create_spatial_indices
# then restart Martin so it picks up the new indices
docker service update --force resilienceatlas-staging_martin
```

### `rake cartodb:fix_invalid_geometries`

Repairs invalid or corrupt geometries in all `ra_vector` tables using
`ST_MakeValid`.  Invalid geometries crash the PostGIS backend when Martin calls
`ST_AsMVTGeom`, producing silent tile errors.  `import_tables` repairs geometries
automatically; this task backfills older imports.

```bash
bundle exec rake cartodb:fix_invalid_geometries
```

---

## Verification

### `rake cartodb:status`

Prints a per-layer report of current migration state without making any changes.

```bash
bundle exec rake cartodb:status
```

Example output:

```
=== CartoDB Migration Status (2026-05-15 14:30) ===

  Layers with provider=NULL             : 12
  of which unpublished with query (flagged): 12

  ✓ #42 sbtn-natural-land-exceedances
      ✓ public.sbtn_thresholds  (available)
  ✗ #43 sbtn-nitrogen-dep-baselines
      ✗ public.ecoregions2017   (missing)

  All tables imported : 1
  Partial             : 0
  No tables yet       : 11
```

Layers that remain `layer_provider = NULL` after `migrate_tables` either have missing
source tables or are an unusual type that requires manual configuration in the admin UI.

---

## Manual operator review (remaining layers)

After running the full pipeline, any layer still showing `layer_provider = NULL` in
`rake cartodb:status` needs manual attention in the Admin → Layers screen:

1. Filter by `layer_provider IS NULL`.
2. Examine `cartodb_migration.tables` in `layer_config` to see which tables are still missing.
3. Decide the appropriate provider:

   | Scenario | Provider | Notes |
   |----------|---------|-------|
   | Vector geometry served by Martin | `martin` | Ensure the table is in `ra_vector` |
   | Raster COG on S3 | `cog` | Set `body.source` to the S3 URL |
   | External WMS | `wms` | Set `body.url` |

4. Set `published = true` when the configuration is complete.

---

## Troubleshooting

**`No export source found`**  
Set `CARTODB_S3_BUCKET` (with valid AWS credentials) or `CARTODB_EXPORT_DIR`
pointing to a local directory with `.csv.gz` files.

**Tables already in the database are skipped**  
Pass `FORCE=1` to overwrite existing tables in `CARTODB_IMPORT_SCHEMA`.

**`WARNING: referenced by layers but NOT found on S3`**  
The task found table names in layer SQL that have no corresponding file on S3.
Check that the `.gpkg` or `.csv.gz` export for that table exists at the expected
prefix and that the `CARTODB_VECTORS_S3_PREFIX` / `CARTODB_TABLES_S3_PREFIX` env
vars match where the files were uploaded.

**`No formerly CartoDB layers found`**  
`update_layer_references` targets `layer_provider IS NULL AND published = false`.
If someone already set a provider manually, use `rake cartodb:status` to inspect
the current state.

**Re-running after adding more tables**  
All tasks are safe to re-run.  `import_tables` skips already-present tables
(use `FORCE=1` to overwrite).  `update_layer_references` refreshes availability.
`configure_cog_layers` and `configure_martin_layers` only process layers that are
still `layer_provider = NULL`; the `fix_*` tasks process all layers of their type.

**COG tiles render as scattered dots or wrong colours**  
Run `rake cartodb:fix_cog_styles` — the colormap was likely stored in the wrong
format for the layer's CartoDB coloriser mode (discrete, exact, or linear).

**Martin layer tiles return 404**  
Run `rake cartodb:fix_martin_sources` — `body.source` may contain an `ra_vector.`
prefix that Martin does not recognise.

**Multi-table COG layer shows only one region**  
Run `rake cartodb:fix_cog_sources` — `body.sources` may be missing or incomplete.

**Raster layer renders data outside the expected country boundary**  
Run `rake cartodb:fix_cog_clip` — the layer uses `ST_CLIP` SQL but `body.clip_geometry`
may not yet be stored.  Ensure the boundary table is present in the `ra_vector` schema
(check with `rake cartodb:status`) then re-run the fix task.

**Click popup shows nothing for a Martin vector layer**  
Run `rake cartodb:fix_martin_interactivity` — `interaction_config` may be empty or missing.
If the table has no non-geometry columns, the popup will always be empty by design.
Use `FORCE=1` to overwrite an existing (possibly stale) config.

**Click popup shows nothing for a COG raster layer**  
Run `rake cartodb:fix_cog_interactivity` — `interaction_config` may be missing.
Confirm the TiTiler service is reachable and the `titilerUrl` env var is set correctly.
