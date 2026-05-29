# Resilience Atlas

[![Backend Tests](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/backend_tests.yml/badge.svg)](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/backend_tests.yml)
[![Frontend Tests](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/frontend_tests.yml/badge.svg)](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/frontend_tests.yml)
[![Integration Tests](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/integration_tests.yml/badge.svg)](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/integration_tests.yml)

## Architecture

| Directory | Description | Documentation | Tech Stack |
|-----------|-------------|---------------|------------|
| frontend | Frontend application | [frontend/README.md](frontend/README.md) | React 19.2.0, Next.js 16.1.1, Node.js 24.0.0 |
| backend | Ruby on Rails backend (API + backoffice) | [backend/README.md](backend/README.md) | Ruby 3.4.8, Rails 7.2.x |
| cloud_functions | AWS Lambda functions | [cloud_functions/README.md](cloud_functions/README.md) | AWS Lambda |
| infrastructure | Terraform for TiTiler COG tiler | [infrastructure/README.md](infrastructure/README.md) | Terraform, AWS |
| data | Data processing scripts | [data/README.md](data/README.md) | Various tools |

## Environments

- **Production**: [resilienceatlas.org](https://resilienceatlas.org) (deployed from `main` branch)
- **Staging**: [staging.resilienceatlas.org](https://staging.resilienceatlas.org) (deployed from `staging` branch)

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)

### Development Setup

1. **Set up environment variables**
   ```bash
   cp .env.example .env
   cp frontend/.env.example frontend/.env
   cp backend/.env.sample backend/.env
   ```

2. **Start the development environment**
   ```bash
   docker compose -f docker-compose.dev.yml up --build
   ```
   
   This starts:
   - PostgreSQL database on port 5432
   - Backend API on http://localhost:3001
   - Frontend application on http://localhost:3000

3. **Admin Panel Access**
   
   The admin panel is available at http://localhost:3001/admin with the following default credentials:
   
   | Field | Value |
   |-------|-------|
   | Email | `admin@example.com` |
   | Password | `password` |

4. **Database Seeding**

   Seeds run automatically on the first start (when the database is empty) and are **skipped on subsequent starts**. To re-seed:
   ```bash
   # Force seeds on next startup
   FORCE_SEED=true docker compose -f docker-compose.dev.yml up backend

   # Or run seeds manually against a running container
   docker compose -f docker-compose.dev.yml exec backend bundle exec rails db:seed
   ```

### Hybrid Development (Database in Docker, Apps Local)

For faster development iteration, you can run only the database in Docker while running the frontend and backend locally:

1. **Start only the database and martin**
   ```bash
   docker compose -f docker-compose.dev.yml up -d db martin
   ```

2. **Start the backend** (requires Ruby 3.4.8)
   ```bash
   cd backend
   bundle install
   bin/rails db:setup    # First time only
   bin/rails server -p 3001
   ```

3. **Start the frontend** (requires Node.js 24.0.0)
   ```bash
   cd frontend
   npm install
   npm run dev
   ```

The frontend will be available at http://localhost:3000 and the backend at http://localhost:3001.

> **Note**: This approach requires having the correct Ruby and Node.js versions installed locally. Use the full Docker setup if you don't have these versions available.

## Running Tests

### Backend Tests
```bash
# Run all backend tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test

# Individual commands
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec    # Unit tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint     # StandardRB
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test security # Brakeman
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test system   # Browser tests
```

### Frontend Tests
```bash
# Run all frontend checks
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test

# Individual commands
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test lint
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test type-check
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test build
```

### Integration Tests
```bash
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

## Vector Tiles (Martin)

[Martin](https://maplibre.org/martin/) is a Rust-based vector tile server that can serve PostGIS MVT functions and MBTiles files. Martin is used for serving vector data layers from the database.

### CDN (CloudFront)

Martin tiles are cached at the edge via CloudFront:

```
Browser → CloudFront (SSL + caching) → ALB (HTTP, host-header routing) → Martin
```

| Environment | URL | Cache TTL |
|-------------|-----|-----------|
| Production  | `https://martin.resilienceatlas.org` | 7 days |
| Staging     | `https://martin.staging.resilienceatlas.org` | 1 day |

**Deploy/update the CDN stack:**
```bash
infrastructure/martin-cdn/deploy.sh --staging --profile resilienceatlas
infrastructure/martin-cdn/deploy.sh --production --profile resilienceatlas
```

**Invalidate cache** (after changing tile sources or data):
```bash
scripts/invalidate-martin-cache.sh --staging --profile resilienceatlas
# Or invalidate specific paths:
scripts/invalidate-martin-cache.sh --staging --paths "/your_tiles/*" --profile resilienceatlas
```

## Boundary Data (Mapbox Streets Vector Tiles)

Admin boundary lines are served via **Mapbox Streets V4 Vector Tiles API**, eliminating self-hosted boundary infrastructure.

**Data Source:**
- Tileset: `mapbox.mapbox-streets-v8` (official Mapbox Streets)
- API: `https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/{z}/{x}/{y}.mvt?access_token={token}`
- Source-layer: `admin` (admin_level 0-2: countries, first-level divisions, second-level divisions)
- Access token: Hardcoded in `frontend/src/views/components/Map/OLMap/boundaries.ts`

**User Interface:**
- Three mutually exclusive options (matching labels pattern):
  - **Dark boundaries**: For light backgrounds
  - **Light boundaries**: For dark backgrounds/satellite
  - **No boundaries**: Boundaries disabled
- URL persistence: `?boundaryStyle=dark|light` (omitted when 'none')

**Implementation:**
- Frontend: OpenLayers VectorTileLayer with custom styling
- Filters: Admin source-layer only, excludes maritime boundaries
- Styling: Halo + line two-layer pattern for visibility
- Redux state: `map.boundaryStyle` ('dark' | 'light' | 'none')
- Code: `frontend/src/views/components/Map/OLMap/boundaries.ts`

**Benefits:**
- Zero infrastructure maintenance (no database, imports, or tile server)
- Professional boundary data from Mapbox
- Vector tiles with transparency for proper overlay rendering
- 200,000 requests/month free tier
- Global CDN caching

## Documentation

- [Testing Documentation](.github/TESTING.md)
- [TiTiler COGs Service](.github/TITILER_COGS.md)
- [Scripts Documentation](scripts/README.md)
- [Frontend README](frontend/README.md)
- [Backend README](backend/README.md)

## License

See [LICENSE](LICENSE) for details.
