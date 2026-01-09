# Testing Workflows

This document describes the comprehensive testing strategy implemented for the Resilience Atlas project using Docker-based workflows.

## Overview

The testing infrastructure consists of three main workflows that run automatically on every push and pull request:

1. **Backend Tests** - Unit, integration, and security tests for the Rails backend
2. **Frontend Tests** - Unit, integration, and E2E tests for the Next.js frontend  
3. **Integration Tests** - Full-stack tests that verify frontend-backend communication

## Workflow Details

### Backend Tests (`backend_tests.yml`)

**Triggers:**
- Push/PR to `backend/` directory
- Manual dispatch

**Test Types:**
- **RSpec Unit Tests**: Model, service, and controller tests
- **RuboCop Linting**: Code style and format validation
- **Brakeman Security**: Security vulnerability scanning
- **Bundle Audit**: Dependency vulnerability checking

**Features:**
- Uses PostgreSQL with PostGIS for realistic database testing
- Docker caching for faster builds
- JUnit test reporting for GitHub integration
- Coverage report collection

### Frontend Tests (`frontend_tests.yml`)

**Triggers:**
- Push/PR to `frontend/` directory
- Manual dispatch

**Test Types:**
- **Jest Unit Tests**: Component and utility function tests
- **ESLint**: Code style and error detection
- **TypeScript Check**: Type validation
- **Build Verification**: Ensures application builds successfully
- **Cypress E2E Tests**: End-to-end user journey testing (Chrome & Firefox)

**Features:**
- Multi-browser testing (Chrome and Firefox)
- Full application build validation
- Test artifacts collection (screenshots, videos)
- Coverage reporting

### Integration Tests (`integration_tests.yml`)

**Triggers:**
- Push/PR to `develop` or `main` branches
- Manual dispatch

**Test Types:**
- **API Integration Tests**: Backend RSpec tests focused on API endpoints
- **Full-Stack E2E Tests**: Cypress tests with real backend data
- **Performance Tests**: Basic response time validation
- **Data Consistency Tests**: Verify data flows correctly between systems

**Features:**
- Matrix testing across multiple browsers
- Complete environment setup (database, backend, frontend)
- Service health verification
- Cross-service communication testing
- Performance benchmarking

## Docker Test Environment

### Services

The `docker-compose.test.yml` defines the following services:

- **db-test**: PostgreSQL with PostGIS for database testing
- **redis-test**: Redis for caching and session storage
- **backend-test**: Rails application in test mode
- **frontend-test**: Next.js application in test mode  
- **cypress-chrome/firefox**: E2E testing containers

### Health Checks

All services include health checks to ensure reliable test execution:
- Database: `pg_isready` check
- Redis: `redis-cli ping` check
- Backend: HTTP health endpoint check
- Frontend: HTTP availability check

### Test Data

- Fresh database created for each test run
- Seeded with test data for consistent E2E testing
- Isolated environments prevent test interference

## Docker Images

### Multi-Stage Builds

Both frontend and backend use multi-stage Dockerfiles:

**Backend Stages:**
- `base`: Common dependencies and Ruby setup
- `test`: Includes Chrome for system tests and test gems
- `production`: Optimized for deployment

**Frontend Stages:**
- `base`: Common Node.js setup
- `deps`: Production dependencies only
- `dev-deps`: All dependencies including dev tools
- `test`: Test environment with curl for health checks
- `builder`: Build stage for production assets
- `production`: Optimized runtime image

## Environment Configuration

### Test Environment Variables

**Backend:**
```bash
RAILS_ENV=test
DATABASE_URL=postgis://postgres:postgres@db-test:5432/resilienceatlas_test
SECRET_KEY_BASE=test_secret_key...
DEVISE_KEY=test_devise_key...
REDIS_URL=redis://redis-test:6379/0
```

**Frontend:**
```bash
NODE_ENV=test
NEXT_PUBLIC_API_HOST=http://backend-test:3001
NEXT_PUBLIC_GOOGLE_ANALYTICS=GA_TEST_ID
# ... other test API keys
```

## Running Tests Locally

### Prerequisites

```bash
# Ensure Docker and Docker Compose are installed
docker --version
docker-compose --version
```

### Backend Tests

```bash
# Run all backend tests
docker-compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "bundle exec rspec"

# Run specific test types
docker-compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "bundle exec standardrb"

docker-compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "bundle exec brakeman"
```

### Frontend Tests

```bash
# Run Jest unit tests
docker-compose -f docker-compose.test.yml run --rm frontend-test \
  bash -c "npm run test:unit"

# Run ESLint
docker-compose -f docker-compose.test.yml run --rm frontend-test \
  bash -c "npm run lint"

# Run Cypress E2E tests
docker-compose -f docker-compose.test.yml up -d db-test backend-test frontend-test
docker-compose -f docker-compose.test.yml run --rm cypress-chrome \
  bash -c "npx cypress run --browser chrome"
```

### Integration Tests

```bash
# Run full integration test suite
docker-compose -f docker-compose.test.yml up -d
# Wait for services to be healthy
docker-compose -f docker-compose.test.yml run --rm cypress-chrome \
  bash -c "npx cypress run --browser chrome"
```

### Cleanup

```bash
# Stop all test services and remove volumes
docker-compose -f docker-compose.test.yml down -v
docker system prune -f
```

## CI/CD Integration

### Deployment Dependencies

The deployment workflows are configured to only run after tests pass:

**Staging Deployment:**
- Triggered by pushes to `develop`
- Requires Frontend Tests and Backend Tests to complete successfully

**Production Deployment:**
- Triggered by pushes to `main`  
- Requires Frontend Tests, Backend Tests, and Integration Tests to complete successfully

### Test Reporting

- JUnit XML reports for GitHub test reporting integration
- Test artifacts (screenshots, videos) uploaded on failure
- Coverage reports collected and displayed

### Performance Considerations

- Docker layer caching reduces build times
- Parallel test execution where possible
- Service health checks prevent race conditions
- Cleanup steps ensure no resource leaks

## Troubleshooting

### Common Issues

1. **Service startup timeouts**: Increase health check intervals
2. **Port conflicts**: Ensure test ports (5433, 6380) are available
3. **Docker space issues**: Run `docker system prune -f` regularly
4. **Database connection errors**: Check PostgreSQL container logs

### Debugging Tests

```bash
# View service logs
docker-compose -f docker-compose.test.yml logs backend-test
docker-compose -f docker-compose.test.yml logs frontend-test

# Access running containers
docker-compose -f docker-compose.test.yml exec backend-test bash
docker-compose -f docker-compose.test.yml exec frontend-test bash

# Check service health
docker-compose -f docker-compose.test.yml ps
```

### Test Data Issues

```bash
# Reset test database
docker-compose -f docker-compose.test.yml run --rm backend-test \
  bash -c "RAILS_ENV=test bundle exec rails db:drop db:create db:schema:load"

# Check database contents
docker-compose -f docker-compose.test.yml exec db-test \
  psql -U postgres -d resilienceatlas_test -c "\\dt"
```

## Best Practices

### Test Development

1. **Isolation**: Each test should be independent and not rely on others
2. **Data**: Use factories/fixtures for consistent test data
3. **Cleanup**: Tests should clean up after themselves
4. **Speed**: Focus on fast feedback loops for unit tests
5. **Coverage**: Maintain good test coverage without obsessing over 100%

### Docker Optimization

1. **Layer Caching**: Structure Dockerfiles to maximize cache hits
2. **Multi-stage**: Use appropriate build stages for different environments
3. **Resource Limits**: Set appropriate CPU/memory limits for test containers
4. **Cleanup**: Always clean up test resources after runs

### CI/CD Integration

1. **Fast Feedback**: Run fastest tests first
2. **Parallel Execution**: Use matrix builds where beneficial
3. **Failure Artifacts**: Always collect debug information on failures
4. **Resource Management**: Clean up after tests to prevent resource exhaustion
