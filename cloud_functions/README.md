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
- ✅ CloudFront CDN with edge caching
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
- ✅ CloudFront CDN with 24-hour cache
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

### Required GitHub Variables

| Variable | Description |
|----------|-------------|
| `TITILER_ALLOWED_BUCKETS` | Comma-separated bucket URIs (e.g., `s3://bucket1,gs://bucket2`) |

## SPARC Plots (AWS Lambda - Legacy)

**Location:** [`sparc_plots/`](./sparc_plots/)

⚠️ **Status: Needs Update** - Uses very outdated dependencies (earthengine-api==0.1.232).

This function should be either:
- Modernized to match the new `earth_engine/` pattern
- Deprecated if no longer in use
