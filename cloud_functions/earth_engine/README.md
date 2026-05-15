# Earth Engine Functions - AWS Lambda

AWS Lambda functions for Google Earth Engine analysis, deployed via SAM (Serverless Application Model).

## Overview

This module provides three Lambda functions for Earth Engine operations:

| Function | Endpoint | Method | Description |
|----------|----------|--------|-------------|
| **Histogram** | `/histogram` | POST | Compute histogram statistics for an EE asset within a geometry |
| **Raster Interaction** | `/raster` | GET | Query raster values at a specific point |
| **Download Image** | `/download` | POST | Generate download URLs for EE images |

**Current Version:** Earth Engine API 1.1.0+ on Python 3.14

## Architecture

```
Frontend → CloudFront CDN → API Gateway → Lambda Functions → Earth Engine API
                                               ↓
                                    AWS Secrets Manager (GEE credentials)
```

## API Reference

### POST /histogram

Compute histogram statistics for an Earth Engine asset within a geometry.

**Request Body:**
```json
{
  "assetId": "users/example/asset_name",
  "geometry": {
    "type": "FeatureCollection",
    "features": [{
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[lon1, lat1], [lon2, lat2], ...]]
      }
    }]
  },
  "numBuckets": 20
}
```

**Response:**
```json
{
  "rows": [
    {"min": 0, "max": 10, "count": 150, "percent": 0.15},
    {"min": 10, "max": 20, "count": 300, "percent": 0.30}
  ],
  "fields": {
    "min": {"type": "number"},
    "max": {"type": "number"},
    "count": {"type": "number"},
    "percent": {"type": "number"}
  },
  "total_rows": 20,
  "stats": {
    "min": 0,
    "max": 255,
    "mean": 127.5,
    "stdev": 50.2,
    "sum": 1234567
  }
}
```

### GET /raster

Query raster values at a specific point.

**Query Parameters:**
- `asset_id` (required): Earth Engine asset ID
- `point` (required): JSON array `[longitude, latitude]`

**Example:**
```
GET /raster?asset_id=users/example/asset&point=[-73.5,2.5]
```

**Response:**
```json
{
  "rows": [{"b1": 42, "b2": 128}]
}
```

### POST /download

Generate a download URL for an Earth Engine image.

**Request Body:**
```json
{
  "assetId": "users/example/asset_name",
  "geometry": {
    "type": "Polygon",
    "coordinates": [[[lon1, lat1], [lon2, lat2], ...]]
  },
  "scale": 30,
  "crs": "EPSG:4326",
  "format": "GEO_TIFF"
}
```

**Response:**
```json
{
  "download_url": "https://earthengine.googleapis.com/..."
}
```

## Security

### Credentials Management

GEE credentials are stored securely in **AWS Secrets Manager**, not in the code:

1. Create a secret in AWS Secrets Manager containing the full GEE service account JSON
2. Set the secret ARN in the `GEE_PRIVATE_KEY_SECRET_ARN` environment variable
3. Lambda functions retrieve credentials at runtime

**Required GitHub Secrets:**
| Secret | Description |
|--------|-------------|
| `GEE_SERVICE_ACCOUNT_EMAIL` | Google Earth Engine service account email |
| `GEE_PRIVATE_KEY_SECRET_ARN` | ARN of AWS Secrets Manager secret with GEE private key JSON |
| `AWS_OIDC_ROLE_ARN` | ARN of the IAM role for GitHub OIDC authentication |
| `SAM_ARTIFACTS_BUCKET` | S3 bucket for SAM deployment artifacts |
| `ROUTE_53_ZONE_ID` | Route53 hosted zone ID |
| `ROLLBAR_ACCESS_TOKEN` | (Optional) Rollbar error tracking token |

### Setting up GEE Credentials in AWS Secrets Manager

```bash
# Create the secret (replace with your actual key file content)
aws secretsmanager create-secret \
  --name "resilienceatlas/gee-credentials" \
  --secret-string file://path/to/your/gee-privatekey.json \
  --region us-east-1

# Note the ARN returned - use this for GEE_PRIVATE_KEY_SECRET_ARN
```

---

## Configuring GEE Layers in Resilience Atlas Admin

To enable analysis functionality for a Google Earth Engine layer, configure these fields in the admin panel:

### Basic Layer Setup

**1. Set `layer_provider`:** `gee`

**2. Set `analysis_suitable`:** ✓ (checked)

**3. Set `analysis_type`:** `histogram` (only option for GEE layers)

### Histogram Analysis Configuration

**Set `analysis_query`:**
```
https://ee.resilienceatlas.org/histogram
```

**Set `analysis_body`:**
```json
{
  "assetId": "users/conservationinternational/dataset_name",
  "params": {}
}
```

The frontend will POST to this endpoint with the user-drawn geometry added to the request body.

### Point Query (Raster Interaction) Configuration

To enable click-to-query functionality for a GEE layer:

**Set `interaction_config`:**
```json
{
  "output": [
    {"column": "b1", "property": "Band 1 Value", "type": "number"},
    {"column": "b2", "property": "Band 2 Value", "type": "number"}
  ],
  "config": {
    "url": "https://ee.resilienceatlas.org/raster?asset_id=users/conservationinternational/dataset_name&point=[{{lng}},{{lat}}]"
  }
}
```

The `{{lng}}` and `{{lat}}` placeholders are replaced with click coordinates at runtime.

### Complete GEE Layer Example

Here's a complete configuration for a GEE layer with analysis and point queries:

**layer_provider:** `gee`

**layer_config:**
```json
{
  "type": "tileLayer",
  "body": {
    "url": "https://earthengine.googleapis.com/map/{mapid}/{z}/{x}/{y}"
  }
}
```

**interaction_config:**
```json
{
  "output": [
    {"column": "b1", "property": "Land Cover", "type": "number"}
  ],
  "config": {
    "url": "https://ee.resilienceatlas.org/raster?asset_id=users/conservationinternational/land_cover&point=[{{lng}},{{lat}}]"
  }
}
```

**analysis_suitable:** ✓

**analysis_type:** `histogram`

**analysis_query:**
```
https://ee.resilienceatlas.org/histogram
```

**analysis_body:**
```json
{
  "assetId": "users/conservationinternational/land_cover",
  "params": {}
}
```

### Finding Your Asset ID

Earth Engine asset IDs follow these patterns:
- Public assets: `users/username/asset_name` or `projects/project-id/assets/asset_name`
- ImageCollections: `COPERNICUS/S2` (for Sentinel-2)
- Feature collections: `FAO/GAUL/2015/level0`

Use the [Earth Engine Data Catalog](https://developers.google.com/earth-engine/datasets) to find public asset IDs.

---

## Local Development

### Prerequisites

- Python 3.14+
- AWS SAM CLI
- Docker
- GEE service account credentials

### Setup

1. Install dependencies:
```bash
cd cloud_functions/earth_engine
pip install -r histogram/requirements.txt
```

2. Set environment variables:
```bash
export GEE_PRIVATE_KEY_SECRET_ARN="arn:aws:secretsmanager:..."
export GEE_SERVICE_ACCOUNT="your-account@project.iam.gserviceaccount.com"
```

3. Build with SAM:
```bash
sam build --template template.yaml
```

4. Test locally:
```bash
sam local start-api
```

5. Invoke a function:
```bash
curl -X POST http://localhost:3000/histogram \
  -H "Content-Type: application/json" \
  -d '{"assetId": "...", "geometry": {...}}'
```

## Deployment

Deployment is automated via GitHub Actions on push to the repository.

### Manual Deployment

```bash
sam build --template template.yaml

sam deploy --stack-name earth-engine-production \
  --parameter-overrides \
    FQDN=ee.resilienceatlas.org \
    ZoneId=Z... \
    GeeServiceAccountEmail=account@project.iam.gserviceaccount.com \
    GeePrivateKeySecretArn=arn:aws:secretsmanager:... \
  --capabilities CAPABILITY_IAM \
  --region us-east-1 \
  --resolve-image-repos
```

## Project Structure

```
earth_engine/
├── template.yaml           # SAM template defining all resources
├── samconfig.toml          # SAM CLI configuration
├── README.md               # This file
├── shared/                 # Shared utilities
│   ├── __init__.py
│   └── ee_utils.py         # EE initialization, CORS, response helpers
├── histogram/
│   ├── app.py              # Histogram Lambda handler
│   ├── Dockerfile
│   └── requirements.txt
├── raster_interaction/
│   ├── app.py              # Raster query Lambda handler
│   ├── Dockerfile
│   └── requirements.txt
└── download_image/
    ├── app.py              # Download URL Lambda handler
    ├── Dockerfile
    └── requirements.txt
```

## Migration from Google Cloud Functions

These functions were migrated from Google Cloud Functions to AWS Lambda for:

1. **Unified Infrastructure**: All cloud functions now on AWS, matching TiTiler
2. **Better Security**: Credentials in AWS Secrets Manager instead of bundled files
3. **Modern Dependencies**: Earth Engine SDK 1.1.0+, google-auth (not oauth2client)
4. **CI/CD Integration**: Automated deployment via GitHub Actions
5. **Error Tracking**: Rollbar integration for monitoring

### API Compatibility

The API is **backwards compatible** with the GCF versions:
- Same request/response formats
- Same endpoints (after DNS update)

### Migration Steps

1. Deploy the new AWS Lambda stack
2. Update DNS to point to the new CloudFront distribution
3. Update frontend configuration if needed
4. Deprecate the GCF endpoints after verification

## Error Handling

All functions return consistent error responses:

```json
{
  "error": "Error message",
  "details": "Additional context (optional)"
}
```

HTTP Status Codes:
- `200`: Success
- `400`: Bad request (missing/invalid parameters)
- `404`: Asset not found
- `500`: Internal server error

## Troubleshooting

### Common Issues

1. **"GEE_PRIVATE_KEY_SECRET_ARN environment variable is required"**
   - Ensure the secret ARN is correctly set in the SAM template parameters

2. **"Failed to retrieve GEE credentials"**
   - Check IAM permissions for Secrets Manager access
   - Verify the secret exists and contains valid JSON

3. **"Earth Engine error"**
   - Check the asset ID is correct and accessible
   - Verify the service account has Earth Engine access

### Logs

View Lambda logs in CloudWatch:
```bash
aws logs tail /aws/lambda/earth-engine-production-histogram --follow
```
