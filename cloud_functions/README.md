# Resilience Atlas Cloud Functions

AWS Lambda functions used by the Resilience Atlas for raster analysis and tile serving.

## Overview

| Function Suite | Description | Runtime | Deployment |
|----------------|-------------|---------|------------|
| **Earth Engine** | Histogram, raster query, image download for GEE layers | Python 3.14 | AWS SAM via GitHub Actions |
| **TiTiler** | Dynamic COG tile server with analysis endpoints | Python 3.14 | AWS SAM via GitHub Actions |

## Analysis Functionality by Layer Type

| Layer Provider | Tile Rendering | Histogram Analysis | Point Query | Download |
|----------------|----------------|-------------------|-------------|----------|
| **COG** | TiTiler `/tiles` | TiTiler `/statistics` via backend proxy | TiTiler `/point` via backend proxy | TiTiler `/preview` |
| **GEE** | Earth Engine tiles | Earth Engine `/histogram` | Earth Engine `/raster` | Earth Engine `/download` |
| **CartoDB** | CartoDB tiles | SQL API | UTFGrid | N/A |

## Earth Engine Functions (AWS Lambda)

**Location:** [`earth_engine/`](./earth_engine/)

Three Lambda functions for Google Earth Engine operations:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/histogram` | POST | Compute histogram statistics for an EE asset |
| `/raster` | GET | Query raster values at a point |
| `/download` | POST | Generate download URLs for EE images |

**Features:**
- ✅ Modern Earth Engine SDK 1.1.0+
- ✅ Secure credentials via AWS Secrets Manager
- ✅ Automated CI/CD via GitHub Actions
- ✅ CloudFront routing with authenticated responses uncached
- ✅ Rollbar error tracking

See [`earth_engine/README.md`](./earth_engine/README.md) for full documentation.

## TiTiler COGs (AWS Lambda)

**Location:** [`titiler_cogs/`](./titiler_cogs/)

Dynamic tile server for Cloud Optimized GeoTIFFs (COGs) with full analysis support.

**TiTiler Endpoints:**
| Endpoint | Description |
|----------|-------------|
| `/tiles/WebMercatorQuad/{z}/{x}/{y}` | Get map tiles |
| `/statistics` | Compute histogram within a geometry |
| `/point/{lon}/{lat}` | Query raster values at a point |
| `/info` | Get COG metadata (bounds, bands) |

**Backend Proxy Endpoints (avoids CORS):**
| Backend Endpoint | TiTiler Endpoint |
|------------------|------------------|
| `/api/titiler/info` | `/info` |
| `/api/titiler/statistics` | `/statistics` |
| `/api/titiler/point` | `/point/{lon}/{lat}` |

**Features:**
- ✅ TiTiler 1.1.0 on Python 3.14
- ✅ S3 and GCS bucket whitelisting
- ✅ CloudFront routing with authenticated responses uncached
- ✅ Full analysis support (histogram, point query)
- ✅ Rollbar error tracking

See [`titiler_cogs/README.md`](./titiler_cogs/README.md) for full documentation including admin configuration examples.

## Deployment

All functions are deployed automatically via GitHub Actions:

- **On push to feature branches:** Deploys to staging environment
- **On push to `main`:** Deploys to production environment
- **On branch deletion:** Cleans up feature branch stacks

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_OIDC_ROLE_ARN` | IAM role for GitHub OIDC authentication |
| `AWS_REGION` | AWS region (e.g., `us-east-1`) |
| `SAM_ARTIFACTS_BUCKET` | S3 bucket for SAM artifacts |
| `ROUTE_53_ZONE_ID` | Route53 hosted zone ID |
| `GEE_SERVICE_ACCOUNT_EMAIL` | Google Earth Engine service account |
| `GEE_PRIVATE_KEY_SECRET_ARN` | Secrets Manager ARN for GEE credentials |
| `ROLLBAR_ACCESS_TOKEN` | Rollbar error tracking token |
| `DATA_GATEWAY_SECRET` | Server-only random signing secret, at least 32 bytes; identical in Rails, TiTiler, Earth Engine and AI stacks for this environment |

### Required GitHub Variables

| Variable | Description |
|----------|-------------|
| `TITILER_ALLOWED_BUCKETS` | Comma-separated bucket URIs (e.g., `s3://bucket1,gs://bucket2`) |
| `EARTH_ENGINE_API_URL` | Fixed HTTPS origin of this environment's EE API, e.g. `https://ee.resilienceatlas.org` (passed to Rails) |
| `ADMIN_API_SYSTEM_USER_ID` | ID of a real, dedicated Rails superadmin service account for pipeline/embedding jobs |
| `TITILER_PUBLIC_URLS` | Optional exact COG URIs approved for anonymous access; empty by default, no prefixes or wildcards |
| `EE_PUBLIC_ASSET_IDS` | Optional exact EE assets approved for anonymous access; empty by default |

### Data authorization and coordinated rollout

The bucket allowlist is **not** a data-access grant. TiTiler and Earth Engine
reject source reads unless the exact resource is explicitly public or carries a
short-lived server HMAC in `X-Data-Authorization`. Never expose
`DATA_GATEWAY_SECRET` through `NEXT_PUBLIC_*`, browser configuration, logs or URLs.
Use different random secrets for production and staging. Rotate Rails, the AI
action group and both data suites together; old signatures expire within 90 seconds.

Browser map tiles, metadata, analysis and point queries must use the Rails
`/api/layers/:id/tiles/...`, `/api/titiler/...` and `/api/earth-engine/...`
gateways. These check publication, actual scope membership and protected-scope
authentication, and return private/no-store responses. GEE catalogue URLs point
to the tile gateway rather than exposing upstream map tokens. Downloads still
require normal application authorization. A public upstream dataset remains
public independently of the application's catalogue.

The shared-key admin service API additionally requires `X-Admin-User-Id`. The
actor's current database role and assignments are authoritative: superadmins
are unrestricted, admins manage assigned scopes, and contributors/staff only
create unpublished layers in assigned scopes. SQL-view mutation endpoints are
disabled; use a reviewed database migration. Do not send the shared key to
browsers or accept actor identity from browser-supplied headers.

Rollout order (coordinate a maintenance window; do not leave old public origins):

1. Configure the environment secrets/variables above and create the dedicated
   service account. Review each explicit public-resource allowlist.
2. Run pending Rails migrations, including
   `20261111143000_secure_public_tile_sources.rb`. Existing layers start with
   `public_data=false`; only superadmins may explicitly approve public vector
   sources. Protection of any assigned scope prevents public Martin serving.
3. Deploy the Rails gateways, frontend, AI functions, EE/TiTiler templates and
   guarded Martin configuration together, restarting Martin to disable its
   origin memory cache. Saved, scope-assigned drafts use
   five-minute, actor-bound preview capabilities; save source changes before
   previewing. Unsaved styling remains previewable.
4. Apply the API CDN template and data-service distributions with caching disabled.
   Invalidate **all old API, TiTiler, EE and Martin cached responses** before
   reopening traffic. When revoking public approval or protecting a previously
   public scope, invalidate Martin again; browser copies cannot be recalled.
   Martin's origin memory cache is disabled so revocation reaches the database
   after CDN invalidation.
5. Restrict storage buckets and any obsolete public EE/GCP/SPARC origins. The
   legacy GCP Cloud Run module now revokes anonymous invocation; migrate callers
   to the authenticated AWS/Rails workflow rather than restoring public invocation.
6. Verify anonymous private-source requests fail at **both CDN and direct origin**;
   verify a valid scope token works only for that scope, drafts require authorized
   previews, revoked actors lose preview access, and unapproved Martin tables fail.

Applying source changes alone does not revoke already issued upstream URLs,
cached responses, public object policies or obsolete deployments. Inventory live
origins and revoke old EE map tokens/download capabilities where supported.

## SPARC Plots (AWS Lambda - Legacy)

**Location:** [`sparc_plots/`](./sparc_plots/)

⚠️ **Status: Needs Update** - Uses very outdated dependencies (earthengine-api==0.1.232).

This function should be either:
- Modernized to match the new `earth_engine/` pattern
- Deprecated if no longer in use
