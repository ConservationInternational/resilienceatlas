# Resilience Atlas Development Instructions

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Environment Setup
- **CRITICAL**: Use Docker for all development - local Node.js (20.19.4) and Ruby (3.2.3) versions do not match requirements (Node.js 22.11.0, Ruby 3.4.4)
- Environment files setup:
  ```bash
  cp .env.example .env
  cp frontend/.env.example frontend/.env  
  cp backend/.env.sample backend/.env
  ```
- Edit environment files with development values (see examples in .env files)

### Development Environment
- **Database startup**: `docker compose -f docker-compose.dev.yml up -d db` - takes < 1 second, ready in ~30 seconds
- **Full development**: `docker compose -f docker-compose.dev.yml up -d` - starts PostgreSQL + PostGIS, backend Rails server, frontend Next.js server
- **Ports**: Frontend http://localhost:3000, Backend http://localhost:3001, Database localhost:5432
- **NEVER CANCEL**: Initial Docker builds take 5-15 minutes depending on network conditions. Set timeout to 25+ minutes.

### Frontend Development (Next.js 14.2.15 + React 18.3.1 + TypeScript)
- **Dependencies**: `cd frontend && npm install --legacy-peer-deps` - takes 5+ minutes. NEVER CANCEL. Set timeout to 10+ minutes.
- **Linting**: `./bin/test lint` - takes ~13 seconds, may show TypeScript `any` type warnings (normal)
- **Type check**: `./bin/test type-check` - takes ~6 seconds
- **Prettier**: `./bin/test prettier` - takes ~3 seconds  
- **Build**: `./bin/test build` - takes ~54 seconds, may show Edge Runtime warnings (normal)
- **All checks**: `./bin/test all` - runs lint, type-check, prettier, build sequentially
- **Dev server**: `npm run dev` - starts in ~2 seconds on port 3000

### Backend Development (Ruby on Rails 7.2.x + PostgreSQL + PostGIS)
- **CRITICAL**: Must use Docker - Ruby 3.4.4 and specific gems required
- **Dependencies**: `bundle install` - takes 2-5 minutes in Docker. NEVER CANCEL. Set timeout to 10+ minutes.
- **Linting**: `./bin/test lint` - StandardRB code style checking
- **Security**: `./bin/test security` - Brakeman security analysis  
- **Audit**: `./bin/test audit` - Bundle Audit for dependency vulnerabilities
- **Tests**: `./bin/test rspec` - RSpec test suite (excludes system tests by default)
- **System tests**: `./bin/test system` - Browser tests with Chrome + Xvfb
- **All tests**: `./bin/test all` - runs linting, security, audit, and RSpec tests

#### Common Backend Test Issues (Fixed in #278)
- **OEmbed Controller**: Fixed "undefined method 'host' for String" by adding proper exception handling
- **File Upload Permissions**: Enhanced Docker container permission setup for photo uploads
- **Globalize Translations**: Fixed Source model attributes method to handle translation objects properly
- **Quick fix validation**: Run `./validate-278-fixes.sh` to verify these fixes are present

### Test Infrastructure
- **CRITICAL**: `./validate-test-infrastructure.sh` - comprehensive test setup validation. NEVER CANCEL. Takes 10-15 minutes. Set timeout to 20+ minutes.
- **Test environment**: `docker compose -f docker-compose.test.yml up --abort-on-container-exit` - full test suite
- **Backend tests only**: `docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test`
- **Frontend tests only**: `docker compose -f docker-compose.test.yml run --rm frontend-test ./bin/test`

### Build Timing Expectations
- **NEVER CANCEL**: Docker builds for backend take 10-25 minutes on first run due to system dependencies and Chrome installation
- **NEVER CANCEL**: Docker builds for frontend take 5-10 minutes due to npm dependencies  
- **NEVER CANCEL**: Test infrastructure setup takes 10-15 minutes for complete validation
- **NEVER CANCEL**: Network issues may cause builds to retry - this is normal, wait for completion
- **Database setup**: PostgreSQL + PostGIS ready in ~30 seconds
- **Frontend dev server**: Ready in ~2 seconds after dependencies installed
- **Backend dev server**: Ready in ~30 seconds after database connection established

### Network Configuration for Docker Builds
Docker builds may fail due to DNS resolution issues. If you encounter `Temporary failure resolving` errors:
```bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf.backup > /dev/null
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf.backup > /dev/null  
sudo cp /etc/resolv.conf.backup /etc/resolv.conf
```
The Dockerfiles include retry logic, but network configuration may be needed in CI environments.

## Validation Scenarios

### Always Test After Changes
1. **Frontend validation**:
   ```bash
   cd frontend
   ./bin/test lint && ./bin/test type-check && ./bin/test prettier && ./bin/test build
   ```
2. **Backend validation** (requires Docker):
   ```bash
   docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint
   docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test security
   ```
3. **Full integration**: Run `./validate-test-infrastructure.sh` to ensure all components work together

### Manual Testing Scenarios
- **Frontend**: After build, start dev server and verify it loads (may show Transifex errors - normal in dev)
- **Backend**: Verify Rails server responds to health checks
- **Database**: Confirm PostgreSQL + PostGIS extensions are working
- **Docker health**: All containers start and pass health checks

### Quick Development Validation
For rapid development without full Docker builds:
1. **Environment setup**: Verify env files exist and have proper values
2. **Frontend dependencies**: `cd frontend && npm install --legacy-peer-deps` (5+ minutes)
3. **Frontend build**: `cd frontend && ./bin/test build` (~1 minute)
4. **Frontend linting**: `cd frontend && ./bin/test lint` (~13 seconds)
5. **Database**: `docker compose -f docker-compose.dev.yml up -d db` (30 seconds to ready)

### End-to-End Validation (When Needed)
Full validation should be done for major changes:
1. Run complete infrastructure validation: `./validate-test-infrastructure.sh` (15+ minutes)
2. Verify all GitHub Actions workflows would pass
3. Test both development and test Docker environments
4. Verify deployment processes work

## Critical Dependencies

### Required Software Versions
- **Node.js**: 22.11.0 (specified in frontend/.nvmrc and Dockerfile)
- **Ruby**: 3.4.4 (specified in backend/.ruby-version and Gemfile)
- **PostgreSQL**: 15 with PostGIS 3.3 (from docker images)
- **Docker**: Required for all development and testing

### Package Manager Commands
- **Frontend**: `npm install --legacy-peer-deps` (legacy flag required for dependency compatibility)
- **Backend**: `bundle install` (with retry logic for network resilience)
- **Docker**: Use buildx for enhanced build features

### Network Dependencies
- DNS configuration may be needed: `echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf.backup && sudo cp /etc/resolv.conf.backup /etc/resolv.conf`
- Transifex CDN for translation services (may fail in restricted environments)
- Cypress CDN for E2E testing tools
- NPM registry and RubyGems for package downloads

## Common Issues and Solutions

### Common Issues and Solutions

### Build Failures
- **DNS resolution errors**: Configure DNS as shown in Network Configuration section
- **Network timeouts**: Builds include retry logic, wait for completion - NEVER CANCEL
- **Chrome installation failures**: System tests require Chrome + Xvfb in Docker - full build can take 20+ minutes
- **Dependency conflicts**: Use `--legacy-peer-deps` for npm, check Ruby/Node versions
- **Package installation errors**: System dependencies may require multiple attempts, builds will retry automatically

### Runtime Issues  
- **Frontend 500 errors**: Usually invalid Transifex credentials (normal in dev), or missing backend connection
- **Backend connection errors**: Ensure PostgreSQL container is running and healthy
- **CORS issues**: Check BACKEND_URL and FRONTEND_URL environment variables
- **Permission errors**: Docker user permissions may need adjustment, especially for Chrome in system tests

### Performance
- **Slow builds**: First-time Docker builds download many dependencies - this is expected, NEVER CANCEL
- **Memory issues**: System tests require adequate RAM for Chrome, at least 2GB
- **Network issues**: Many dependencies downloaded, ensure good connectivity, builds will retry on failure

## Getting Started Checklist

For a fresh repository clone, follow these exact steps:

### 1. Environment Setup (< 1 minute)
```bash
# Copy environment files
cp .env.example .env
cp frontend/.env.example frontend/.env  
cp backend/.env.sample backend/.env

# Edit .env files with development values (see file contents for examples)
```

### 2. Quick Validation (5-10 minutes)
```bash
# Install frontend dependencies - NEVER CANCEL, takes 5+ minutes
cd frontend && npm install --legacy-peer-deps

# Test frontend builds and checks - takes ~1 minute total
./bin/test type-check && ./bin/test prettier && ./bin/test build

# Start database - ready in ~30 seconds
cd .. && docker compose -f docker-compose.dev.yml up -d db
```

### 3. Full Development (when needed)
```bash
# Start complete development environment
docker compose -f docker-compose.dev.yml up -d

# Or run full test infrastructure validation - NEVER CANCEL, takes 15+ minutes
./validate-test-infrastructure.sh
```

### 4. Before Committing Changes
```bash
# Frontend changes
cd frontend && ./bin/test all

# Backend changes (requires Docker)
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test security
```

## Running Tests Locally

### Frontend Unit Tests and Linting
```bash
cd frontend

# Run all checks (lint, type-check, prettier, build)
./bin/test all

# Individual checks
./bin/test lint        # ESLint - ~13 seconds
./bin/test type-check  # TypeScript - ~6 seconds
./bin/test prettier    # Code formatting - ~3 seconds
./bin/test build       # Next.js build - ~54 seconds
```

### Backend Tests (Requires Docker)
```bash
# Start the test environment (includes db-test, redis-test, backend-test, frontend-test)
docker compose -f docker-compose.test.yml up -d

# Wait for all containers to be healthy (check with `docker compose -f docker-compose.test.yml ps`)

# Run backend linting and tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint      # StandardRB
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test security  # Brakeman
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test audit     # Bundle Audit
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec     # RSpec tests

# Run all backend tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test all
```

### Integration Tests (Cypress - Requires Docker)

Integration tests use Cypress running against a full Docker test environment with frontend, backend, and database.

**1. Start the test environment:**
```bash
docker compose -f docker-compose.test.yml up -d

# Wait for all 4 containers to be healthy:
# - db-test (port 5433)
# - redis-test (port 6380)
# - backend-test (port 3001)
# - frontend-test (port 3000)
docker compose -f docker-compose.test.yml ps  # All should show (healthy)
```

**2. Run Cypress tests using the Cypress Docker image:**
```bash
# Run all integration tests
docker run --rm \
  --network resilienceatlas_test-network \
  -w /app \
  -v "$(pwd)/frontend:/app" \
  -e CYPRESS_baseUrl=http://frontend-test:3000 \
  -e CYPRESS_defaultCommandTimeout=30000 \
  -e CYPRESS_pageLoadTimeout=60000 \
  cypress/included:13.15.0 run --browser chrome

# Run a specific test file
docker run --rm \
  --network resilienceatlas_test-network \
  -w /app \
  -v "$(pwd)/frontend:/app" \
  -e CYPRESS_baseUrl=http://frontend-test:3000 \
  -e CYPRESS_defaultCommandTimeout=30000 \
  cypress/included:13.15.0 run --browser chrome --spec "cypress/e2e/home.cy.js"
```

**3. Alternative: Run tests from host machine with local Cypress:**
```bash
cd frontend
npm install  # if not already done
npx cypress open  # Opens Cypress GUI, configure baseUrl to http://localhost:3000

# Or headless:
npx cypress run --config baseUrl=http://localhost:3000
```

### Test Architecture Notes

- **Frontend tests** use UI-based assertions (wait for elements) rather than XHR request interception
- **The Map component** is loaded with `ssr: false` (client-side only), requiring extra wait time
- **API data** is fetched client-side via Redux after page hydration, not during SSR
- **Intercepts** (`cy.intercept`) capture browser XHR requests, not server-side calls

### Debugging Integration Test Failures

1. **Screenshot location**: After test failure, check `frontend/cypress/screenshots/`
2. **View container logs**: `docker logs resilienceatlas-frontend-test-1`
3. **Check API connectivity**: `docker exec resilienceatlas-frontend-test-1 curl http://backend-test:3001/api/site`
4. **Interactive debugging**: Run Cypress with `--headed` flag or use Cypress GUI

## Architecture Overview

### Repository Layout
```
/
├── frontend/          Next.js React application
├── backend/           Ruby on Rails API + admin
├── cloud_functions/   AWS Lambda functions
├── infrastructure/    Terraform for AWS resources  
├── data/             Data processing scripts
├── .github/          CI/CD workflows and documentation
└── docker-compose.*  Development and test environments
```

### Frequently Modified Files
- `frontend/src/` - React components and application logic
- `backend/app/` - Rails controllers, models, views
- `backend/spec/` - RSpec tests
- `frontend/cypress/` - E2E test specs
- `.github/workflows/` - CI/CD pipeline definitions

### Always Check After Changes
- Run frontend linting: `cd frontend && ./bin/test lint`
- Run backend linting: `docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint`
- Verify builds work: `cd frontend && ./bin/test build`
- Test infrastructure: `./validate-test-infrastructure.sh` (for major changes)

## CI/CD Integration

### GitHub Actions Workflows
- **Backend Tests** (`backend_tests.yml`): RSpec, StandardRB, Brakeman, Bundle Audit - 30 minute timeout
- **Frontend Tests** (`frontend_tests.yml`): ESLint, TypeScript, Prettier, Build verification - 45 minute timeout  
- **Integration Tests** (`integration_tests.yml`): Full-stack testing
- **Deployment**: Separate workflows for staging (develop branch) and production (main branch)

### Before Committing
- Always run `cd frontend && ./bin/test all` for frontend changes
- Always run backend linting and security checks for backend changes
- Verify builds succeed locally before pushing
- Large changes should include full infrastructure validation

### Deployment Notes
- Staging: Deployed to staging.resilienceatlas.org from develop branch
- Production: Deployed to resilienceatlas.org from main branch
- AWS EC2 deployment with Docker Compose and containerized PostgreSQL for staging
- Automatic database refresh from production to staging on deploy