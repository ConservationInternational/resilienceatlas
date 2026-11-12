# Spatial upload workspace

See the [remaining implementation and release work](./remaining-implementation-work.md)
for the consolidated staging and deployment acceptance gates.

## Administrator workflow

Open **Data > Data Uploads > Upload New Data**. The same workspace is linked from
Dataset Inventory and the layer-specific Import Vector / Upload COG actions.

1. Choose vector or raster and create-draft, dataset-only, or replace from an
   existing layer's action. New layers are always unpublished.
2. Select a file and upload. Bytes go directly to S3 in 16 MiB parts. Interrupted
   parts retry three times. Reopen the saved workspace URL, reselect the same file,
   and resume in the same browser. Per-part SHA-256 fingerprints in browser storage
   prevent combining old parts with a changed file; if storage was cleared, cancel
   and restart rather than resume unsafely.

The spatial workspace uses one native multipart module rather than adding an
Uppy dependency to the admin importmap. This removes the old external Uppy startup
dependency while retaining persisted sessions, actual part listing, retry,
resumption and cancellation. The legacy large-CSV page retains Uppy compatibility.
3. Wait for processing. If requested, choose a listed GeoPackage sublayer or
   supply a missing source CRS as `EPSG:<number>`, apply, and retry processing.
4. Configure display and popup fields. For rasters, choose continuous,
   categorical, or RGB semantics, bands, optional display range/nodata override,
   and optional TiTiler colormap or categorical colormap JSON. RGB bands use
   comma-separated indices, for example `1,2,3`. Source pixel values are not
   rescaled. Changing ingestion options queues a new immutable output.
5. Apply configuration to open the map preview. Inspect geometry or pixel values.
   The backend checks the actual Martin/TiTiler service before allowing save.
   Confirm the preview, then save. Use the existing layer editor to associate
   layer groups/scopes, sources, metadata and publish when ready.

Supported vector formats: GeoPackage, GeoJSON, and ZIP containing exactly one
Shapefile with `.shp`, `.shx`, `.dbf` (supply a source CRS if `.prj` is absent).
Choose one spatial sublayer per GeoPackage import. Archive extraction rejects
unsafe paths/links and enforces entry/expanded-size limits.

Supported raster formats: GeoTIFF and COG, converted/normalized to lossless COG
with internal overviews. Missing CRS may be assigned explicitly, but missing
georeferencing is rejected. Legacy PostGIS raster tables remain readable; this
workflow does not create new `ra_raster` tables.

The existing nonspatial CSV workflow remains in the workspace; it replaces the
named table transactionally and is capped at 50 MB. Scope-dataset large CSV
uploads retain their existing page and use the shared multipart coordinator.

## Tile configuration diagnostics

Use **Map Content > Tile Security**, a layer's security panel, or the CSV export
to inspect `config_diagnostics` when `invalid_provider_config` is reported.
Diagnostics distinguish malformed JSON/object shapes, missing COG sources,
unsupported URL schemes, malformed URLs, and unresolved Martin/Earth Engine
identities. They never include source URLs, credentials, or parser exception text.

COG sources support both `s3://bucket/key.tif` and HTTPS. Keep existing S3
configurations: TiTiler uses its IAM role to read private objects. Do not convert
them to HTTPS or make a bucket public to clear a readiness error.
S3 and equivalent standard AWS HTTPS object URLs share a policy identity, so a
restriction on either alias blocks shared public serving. Rendering still checks
`COG_ALLOWED_S3_BUCKETS` (default `resilienceatlas`) and the HTTPS host allowlist.
Configuration readiness does not establish that the object exists or is readable;
verify anonymous tile delivery after deployment. No data migration or replay of
grandfathering is needed for the S3 identity fix.

## Replacement and recovery

- Processing never overwrites the active table or object. Each output has a new
  table/key, so existing Martin/CDN/browser caches cannot mask replacements.
- Compatible vector/raster configuration, metadata, translations, source and
  scope associations, and publication state remain on the existing layer.
  Vector table-specific style keys are remapped to the new MVT layer name.
- Previous source URLs, multi-file composition and source-specific clipping are
  replaced by the selected dataset. The workspace calls out this source change;
  review retained legends/styles against the new data before confirming.
- Analysis is disabled on replacement until explicitly revalidated in the layer
  editor. Do not assume a prior analysis query matches the new source.
- The target's update timestamp is checked at finalization. If someone edited
  the layer during processing, start a new replacement rather than overwrite it.
- The upload workspace exposes rollback after a replacement. It restores the
  previous source/configuration only if the layer has not subsequently changed.
- Cancel prevents finalization, aborts an open multipart transfer, and leaves the
  current layer untouched. A running GDAL process may finish its bounded current
  work; its result cannot resurrect a cancelled upload.
- Completed and failed outputs are retained. Automatic deletion of processed
  datasets is intentionally not implemented: existing layers, views, and rollback
  history can share them. Inventory and import history support manual review.
  Never delete a source without checking all layer/view references and rollback
  needs.

## Deployment prerequisites

Run migrations before deploying the new web/worker code:

```bash
bundle exec rails db:migrate
bundle exec sidekiq -C config/sidekiq.yml
```

Run these commands in the appropriate backend container. Roll out workers before
enabling the new web entry points, and drain old workers before schema/code
rollback. The migration deliberately cannot restore mandatory polymorphic targets
because standalone datasets no longer use an AdminUser as a pretend target.
Already-queued `VectorImportJob` records are processed by a compatibility wrapper;
they now stop for explicit preview/finalization instead of modifying live layers.

The backend and workers require:

- GDAL (`gdal-bin` in the existing Docker image), PostGIS, and writable
  `tmp/imports`. GDAL 3.6.2 is covered by the real fixture tests.
- S3 access through the AWS credential provider chain (instance/task roles are
  supported), `S3_BUCKET`, and `AWS_REGION`.
- S3 permissions for multipart creation/signing/listing/completion/abort, object
  reads/HEAD, and processed COG writes under `staging/uploads/` and `cogs/imports/`.
- Redis and a healthy worker consuming `imports`. Large jobs share this queue
  with CSV imports; tune worker concurrency against measured RAM/temp-disk usage,
  not just CPU count.
- `MARTIN_URL` pointing to the backend-reachable Martin server with the
  `ra_vector_tile` function and access to `ra_vector`.
- `TITILER_URL` pointing to the same TiTiler environment used by the public map,
  with permission to read processed COGs. When omitted, the existing
  staging/production domain convention is used. Set it explicitly for custom
  deployments to avoid environment ambiguity.
- `FRONTEND_URL` pointing to the matching browser-reachable frontend. The upload
  preview embeds its existing `/admin-preview/layer` page and reuses the actual
  map provider/style implementation, rather than a second CDN-loaded map library.
  The page receives configuration and bounds through origin/source-checked
  messages and returns feature/coordinate samples to the workspace.

S3 bucket CORS must allow exact frontend/admin origins, `PUT`, `GET`, and `HEAD`,
the headers used by presigned uploads, and expose `ETag`. Do not replace unrelated
existing bucket CORS rules. Configure S3's
`AbortIncompleteMultipartUpload` lifecycle rule; no completed COG expiration
should be enabled without reference-aware retention.

Configuration:

| Variable | Default | Meaning |
| --- | --- | --- |
| `UPLOAD_MAX_BYTES` | 5368709120 | Maximum compressed/source upload size, 5 GiB |
| `UPLOAD_PROCESSING_TIMEOUT_SECONDS` | 1800 | Processing time budget |
| `UPLOAD_SESSION_RETENTION_HOURS` | 168 | Abandoned transfer expiration used by reconciliation |

Archive and raster resource limits are additionally enforced by their processors.
These are conservative initial operational ceilings, not performance guarantees.
Benchmark representative large datasets in staging before increasing them.

Schedule the following inside the backend container (for example every 10 minutes):

```bash
bundle exec rake uploads:reconcile
```

It expires abandoned multipart transfers and marks overdue queued/processing
uploads as failed with a recovery message. It does not silently requeue jobs or
delete dataset objects/tables. Investigate worker health before retrying.
Errors include upload IDs in Rails logs and processing errors are reported through
the existing rate-limited Rollbar integration.

## API compatibility

The canonical multipart endpoint is `/api/uploads/multipart`; the former
`/api/v1/uploads/multipart` spelling remains an alias for CSV clients. Operations
are now bound to the authenticated uploader's persisted session and object key;
arbitrary S3 keys are not accepted. Existing open transfers from the old UI must
be restarted after rollout.

Spatial clients use `/api/uploads/sessions` and its processing/configuration/
verification/finalization actions. Completion means transfer completion only;
`ready` means processed and awaiting confirmation; `complete` means the dataset
or layer has been finalized. Failed queue submission is recorded explicitly.

The token-authenticated `/api/admin/vector_tables/import` endpoint reuses vector
inspection and versioned ingestion, returns typed columns and qualified-schema
metadata, and never overwrites an existing destination. Existing-table requests
now receive an explicit validation error directing the caller to the replacement
workspace. Import sources must be in the configured upload bucket. This is an
intentional safety change to the former destructive `-overwrite` behavior.

## Validation and release checklist

Focused backend validation, using Docker:

```bash
docker compose -f docker-compose.test.yml run --rm -e RUN_GDAL_SPECS=1 backend-test \
  bundle exec rspec \
  spec/requests/api/v1/data_uploads_spec.rb \
  spec/requests/api/v1/upload_multipart_spec.rb \
  spec/services/spatial_upload_lifecycle_spec.rb \
  spec/jobs/spatial_upload_job_spec.rb \
  spec/services/vector_upload_processor_spec.rb \
  spec/services/raster_upload_processor_spec.rb \
  spec/services/upload_tile_service_spec.rb \
  spec/services/vector_api_import_spec.rb

docker compose -f docker-compose.test.yml run --rm backend-test \
  bundle exec rspec spec/systems/admin/data_uploads_spec.rb
```

Run backend lint/security and frontend checks as documented in the repository.
The browser specs require the image's non-root user for Chrome. The frontend
regression spec is `frontend/cypress/e2e/vector-upload-style.cy.js`.

Before production, perform the original plan's real staging upload-to-render
matrix with actual S3 CORS/IAM, Martin, TiTiler, CDN and representative large files.
Local tests use stubbed S3 for coordination and real GDAL/PostGIS for conversion
and vector/MVT checks; they do not certify deployed IAM, range reads, CDN, disk
capacity or throughput. Check point/line/polygon and single-/multi-band raster
display, known pixel values, nodata transparency, interrupted resume, concurrent
replacement, cancellation, rollback, and unchanged published-layer behavior.
Run full infrastructure validation before rollout. Do not equate passing local
unit tests with completing this deployment gate.
