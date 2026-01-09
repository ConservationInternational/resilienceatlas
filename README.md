# Resilience Atlas

[![Backend Tests](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/backend_tests.yml/badge.svg)](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/backend_tests.yml)
[![Frontend Tests](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/frontend_tests.yml/badge.svg)](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/frontend_tests.yml)
[![Integration Tests](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/integration_tests.yml/badge.svg)](https://github.com/ConservationInternational/resilienceatlas/actions/workflows/integration_tests.yml)

## Architecture

| Directory | Description | Documentation | Tech Stack |
|-----------|-------------|---------------|------------|
| frontend | Frontend application | [frontend/README.md](frontend/README.md) | React 18.3.1, Next.js 14.2.15, Node.js 22.11.0 |
| backend | Ruby on Rails backend (API + backoffice) | [backend/README.md](backend/README.md) | Ruby 3.4.4, Rails 7.2.x |
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

## Running Tests

### Backend Tests
```bash
# Run all backend tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test

# Individual commands
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec    # Unit tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint     # RuboCop
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

## Documentation

- [Testing Documentation](.github/TESTING.md)
- [TiTiler COGs Service](.github/TITILER_COGS.md)
- [Scripts Documentation](scripts/README.md)
- [Frontend README](frontend/README.md)
- [Backend README](backend/README.md)

## License

See [LICENSE](LICENSE) for details.
