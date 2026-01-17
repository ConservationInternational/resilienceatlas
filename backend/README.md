# Resilience Atlas Backend

Ruby on Rails backend powering [resilienceatlas.org](https://www.resilienceatlas.org) - provides the REST API and admin backoffice.

## Requirements

- Ruby 3.4.8
- Rails 7.2.x
- PostgreSQL 15 with PostGIS
- Docker (recommended)

## Quick Start (Docker - Recommended)

```bash
# From repository root
cp backend/.env.sample backend/.env

# Start database and backend
docker compose -f docker-compose.dev.yml up -d db backend
```

Backend available at http://localhost:3001, admin at http://localhost:3001/admin

**Default admin credentials:** `admin@example.com` / `password`

## Local Development (Without Docker)

```bash
cp .env.sample .env
gem install bundler
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server -p 3001
```

## Running Tests

```bash
# Using Docker (recommended)
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test all

# Individual test commands
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec    # Unit tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint     # StandardRB
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test security # Brakeman
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test audit    # Bundle Audit

# Local (requires PostgreSQL)
bundle exec rspec
```

## Deployment

Deployment is automated via GitHub Actions and AWS CodeDeploy:

- **Staging**: Push to `staging` branch → staging.resilienceatlas.org
- **Production**: Push to `main` branch → resilienceatlas.org

See [scripts/README.md](../scripts/README.md) for deployment details.

## Linting

```bash
# Run linter
bin/rails standard

# Auto-fix issues
bin/rails standard:fix
```

## API Documentation

Interactive API docs available at `/api-docs` when server is running.

```bash
# Generate/update API documentation
SWAGGER_DRY_RUN=0 rake rswag:specs:swaggerize
```

### Base URL and Versioning

- **Base URL**: `/api`
- **Current Version**: `v1` (most endpoints use `/api/v1/`)
- **Content Type**: `application/json`

### Authentication

The API supports multiple authentication methods:

1. **Bearer Token Authentication**
   ```
   Authorization: Bearer <your_token>
   ```

2. **Cookie-based Authentication** (for browser requests)
   ```
   Cookie: _backend_session=<session_value>
   ```

To obtain an authentication token:
```bash
POST /users/authenticate
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password"
}
```

### Interactive API Documentation

Full interactive documentation is available via Swagger UI at `/api-docs` when the server is running. To generate/update the documentation:

```bash
SWAGGER_DRY_RUN=0 rake rswag:specs:swaggerize
```

### Core API Endpoints

#### Data Management

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/layers` | GET | List all layers with filtering | No |
| `/api/layers/{id}/downloads` | GET | Download layer data as ZIP | Optional |
| `/api/layer-groups` | GET | Get layer groups | No |
| `/api/categories` | GET | List categories | No |
| `/api/indicators` | GET | List indicators | No |
| `/api/models` | GET | List models | No |

**Layer Filtering Parameters:**
- `site_scope`: Filter by site scope subdomain
- `locale`: Language (default: 'en')

#### Site & Content Management

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/sites` | GET | List all site scopes | No |
| `/api/site` | GET | Get specific site information | No |
| `/api/homepage` | GET | Get homepage content | No |
| `/api/menu-entries` | GET | Get menu structure | No |
| `/api/static_pages/{slug}` | GET | Get static page content | No |

#### Site Scope Authentication

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/site-scope/authenticate` | POST | Authenticate access to protected site scope | No |
| `/api/site-scope/check-access` | GET | Check authentication status for site scope | No |

**Site Scope Authentication:**
Some site scopes can be password protected. Use these endpoints to handle authentication:

- **Authentication Request Body:**
  ```json
  {
    "site_scope": "subdomain",
    "username": "site_username", 
    "password": "site_password"
  }
  ```

- **Authentication Response:**
  ```json
  {
    "message": "Authentication successful",
    "token": "jwt_token_here",
    "authenticated": true
  }
  ```

- **Using Authentication Token:**
  Include the token in subsequent requests via header:
  ```
  Site-Scope-Token: jwt_token_here
  ```

#### Journey System

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/journeys` | GET | List published journeys | No |
| `/api/journeys/{id}` | GET | Get journey details with steps | No |

**Journey Response includes:**
- Journey metadata (title, subtitle, theme)
- Background images in multiple sizes
- Journey steps with different types (landing, chapter, embed, conclusion)

#### User Management

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/users/register` | POST | Register new user | No |
| `/users/authenticate` | POST | Login and get token | No |
| `/users/me` | GET | Get current user profile | Yes |
| `/users/me` | PATCH | Update user profile | Yes |

#### Sharing & Interaction

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/share` | POST | Create shareable URL | No |
| `/api/share/{uid}` | GET | Retrieve shared content | No |
| `/api/feedbacks` | POST | Submit user feedback | No |
| `/api/photos` | POST | Upload photos | Yes (Cookie) |
| `/services/oembed` | GET | Get oEmbed data for URLs | No |

#### Administrative Endpoints

| Endpoint | Method | Description | Auth Required |
|----------|--------|-------------|---------------|
| `/api/admin/layers` | GET | List layers (admin view) | Yes (Admin) |
| `/api/admin/layers` | POST | Create new layer | Yes (Admin) |
| `/api/admin/layers/{id}` | GET | Get layer details | Yes (Admin) |
| `/api/admin/layers/{id}` | DELETE | Delete layer | Yes (Admin) |
| `/api/admin/layers/site_scopes` | GET | List site scopes | Yes (Admin) |

**Admin Parameters:**
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 30)
- `keyword`: Search term for site scopes

### Response Format

#### Success Responses
```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "current_page": 1,
    "total_pages": 10
  }
}
```

#### Error Responses
Following JSON:API specification:
```json
{
  "errors": [
    {
      "status": "404",
      "title": "Record not found"
    }
  ]
}
```

#### Authentication Errors
```json
{
  "success": false,
  "message": "Invalid API Credentials"
}
```

### Example Requests

#### Get Layers for a Site
```bash
curl -X GET "http://localhost:3000/api/layers?site_scope=resilience&locale=en" \
  -H "Accept: application/json"
```

#### Authenticate User
```bash
curl -X POST "http://localhost:3000/users/authenticate" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "password"
  }'
```

#### Create Share URL
```bash
curl -X POST "http://localhost:3000/api/share" \
  -H "Content-Type: application/json" \
  -d '{
    "body": "{"layers": [1,2,3], "zoom": 5}"
  }'
```

#### Submit Feedback
```bash
curl -X POST "http://localhost:3000/api/feedbacks" \
  -H "Content-Type: application/json" \
  -d '{
    "feedback": {
      "language": "en",
      "feedback_fields_attributes": [
        {
          "feedback_field_type": "single_choice",
          "question": "How satisfied are you?",
          "answer": {"slug": "very-satisfied", "value": "Very Satisfied"}
        }
      ]
    }
  }'
```

#### Authenticate to Protected Site Scope
```bash
curl -X POST "http://localhost:3000/api/site-scope/authenticate" \
  -H "Content-Type: application/json" \
  -d '{
    "site_scope": "protected-site",
    "username": "site_username",
    "password": "site_password"
  }'
```

#### Access Protected Content
```bash
curl -X GET "http://localhost:3000/api/layers?site_scope=protected-site" \
  -H "Site-Scope-Token: your_jwt_token_here" \
  -H "Accept: application/json"
```

### Data Models

#### Layer Object
```json
{
  "id": 123,
  "name": "Population Density",
  "description": "Population density data",
  "slug": "population-density",
  "layer_type": "raster",
  "opacity": 0.8,
  "published": true,
  "analysis_suitable": true,
  "download": true,
  "layer_provider": "gee",
  "zoom_min": 3,
  "zoom_max": 18
}
```

#### Layer Providers

The `layer_provider` field determines how the layer is rendered:

| Provider | Description | Example Use Case |
|----------|-------------|------------------|
| `cartodb` | CartoDB/CARTO vector tiles | Vector overlays, administrative boundaries |
| `gee` | Google Earth Engine | Satellite imagery, global datasets |
| `cog` | Cloud Optimized GeoTIFF via TiTiler | Raster analysis layers from S3/GCS |
| `xyz tileset` | Generic XYZ tile service | Pre-rendered tile caches |

#### COG Layer Configuration

For `cog` layers, the `layer_config` JSON must include the TiTiler tile URL template:

```json
{
  "type": "tileLayer",
  "body": {
    "url": "https://titiler.resilienceatlas.org/tiles/WebMercatorQuad/{z}/{x}/{y}?url=https://storage.googleapis.com/bucket/layer.tif&bidx=1&colormap={{colormap}}"
  },
  "params": {
    "colormap": {"1": [255, 0, 0, 255], "2": [0, 255, 0, 255]}
  }
}
```

**TiTiler URL Parameters:**
- `url`: URL to the COG file (must be from whitelisted bucket)
- `bidx`: Band index (1-based)
- `colormap`: JSON color mapping (use `{{colormap}}` placeholder for frontend substitution)
- `rescale`: Optional rescaling (e.g., `0,100`)

See [TiTiler README](../cloud_functions/titiler_cogs/README.md) for full API documentation.

#### Journey Object
```json
{
  "id": 456,
  "title": "Climate Change Impacts",
  "subtitle": "Understanding regional effects",
  "theme": "climate",
  "published": true,
  "background_image": {
    "small": "url_to_small_image",
    "medium": "url_to_medium_image", 
    "original": "url_to_original_image"
  },
  "journey_steps": [...]
}
```

### Error Handling

The API uses standard HTTP status codes:

- `200` - Success
- `201` - Created (for POST requests)
- `400` - Bad Request
- `401` - Unauthorized (including site scope authentication failures)
- `404` - Not Found
- `422` - Unprocessable Entity (validation errors)

#### Site Scope Authentication Errors

When accessing a protected site scope without proper authentication:

```json
{
  "errors": [
    {
      "status": "401",
      "title": "Site scope authentication required",
      "detail": "This site scope requires authentication. Please authenticate first.",
      "meta": {
        "requires_authentication": true,
        "site_scope": "protected-subdomain"
      }
    }
  ]
}
```

### Rate Limiting

Currently, no rate limiting is implemented, but it's recommended for production deployments.

### CORS Configuration

Cross-Origin Resource Sharing (CORS) is configured to allow requests from authorized domains. Check `config/application.rb` for current CORS settings.
