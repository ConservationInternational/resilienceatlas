# Resilience Atlas

## Architecture

This repository contains all the code and documentation necessary to set up and deploy the project. It is organised in 4 main subdirectories, with accompanying documentation inside each.

| Subdirectory name | Description                                                 | Documentation                                          | Tech Stack                    |
|-------------------|-------------------------------------------------------------|--------------------------------------------------------|-------------------------------|
| frontend          | Frontend application                                        | [frontend/README.md](frontend/README.md)               | React 18.3.1, Next.js 14.2.15, Node.js 22.11.0 |
| backend           | The Ruby on Rails backend application (API + backoffice)    | [backend/README.md](backend/README.md)                 | Ruby 3.4.4, Rails 7.2.x      |
| cloud_functions   | cloud functions code folder                                 | [cloud_functions/README.md](cloud_functions/README.md) | Various AWS Lambda functions  |
| infrastructure    | The Terraform project for TiTiler COG tiler as AWS lambda   | [infrastructure/README.md](infrastructure/README.md)   | Terraform, AWS                |
| data              | data folder where diverse scripts for data management lives | [data/README.md](data/README.md)                       | Various data processing tools |

## CI/CD Process

The project uses GitHub Actions for continuous integration and deployment. The CI/CD workflows are organized into comprehensive testing and deployment categories:

### Testing Workflows

The project implements comprehensive testing with Docker-based workflows:

#### Backend Tests (`backend_tests.yml`)
- **Testing**: RSpec test suite with PostgreSQL database
- **System Tests**: Capybara-based browser tests for admin interface using Chrome
- **Linting**: RuboCop code style checks  
- **Security**: Brakeman security analysis and Bundle Audit for dependency vulnerabilities
- **Triggers**: Runs on pushes/PRs to the `backend/` directory

#### Frontend Tests (`frontend_tests.yml`)
- **Unit Testing**: Jest tests for components and utilities
- **E2E Testing**: Cypress tests on Chrome and Firefox browsers
- **Linting**: ESLint and TypeScript validation
- **Build Verification**: Ensures application builds successfully
- **Triggers**: Runs on pushes/PRs to the `frontend/` directory

#### Integration Tests (`integration_tests.yml`)
- **Full-Stack Testing**: Complete frontend-backend integration testing
- **API Testing**: Backend integration tests focused on API endpoints
- **Performance Testing**: Basic response time validation
- **Data Consistency**: Verifies data flows correctly between systems
- **Triggers**: Runs on pushes/PRs to `develop` and `main` branches

Key testing features:
- Docker-based isolated test environments
- Multi-browser E2E testing (Chrome and Firefox)
- System tests for admin interface using Capybara and Chrome
- Comprehensive test reporting with JUnit integration
- Test artifacts collection (screenshots, videos on failure)
- Health checks and service dependency management

### Build Optimization

The project uses advanced Docker buildx caching strategies to significantly speed up CI/CD builds:

#### Caching Features
- **Content-based cache keys**: Cache invalidation based on Dockerfile and dependency file changes
- **Multi-level fallback**: Progressive cache key fallback for maximum cache reuse
- **GitHub Actions cache**: Persistent caching across workflow runs (10GB limit)
- **Registry-based caching**: Future-ready for cross-repository layer sharing
- **Coordinated builds**: Docker Bake configuration for multi-service coordination

#### Performance Benefits
- **50-80% reduction** in build times for incremental changes
- **90%+ cache hit rate** for dependency-only changes
- **Parallel build execution** with shared cache layers
- **Reduced GitHub Actions minutes** consumption

#### Developer Tools
- **Cache validation script**: `./test-docker-cache.sh` for local testing
- **Cache analytics**: Build-time performance monitoring
- **Documentation**: Comprehensive caching strategy in `.github/DOCKER_CACHE_STRATEGY.md`

Cache keys are generated based on:
- Dockerfile content hashes
- Dependency file hashes (Gemfile.lock, package-lock.json)
- Runtime versions (Ruby, Node.js)
- Daily cache refresh for staleness prevention

See [.github/TESTING.md](.github/TESTING.md) for detailed testing documentation.

### EC2 Deployment Workflows

The project uses AWS EC2 instances for deployment with separate workflows for staging and production:

#### Staging Deployment (`ec2_deploy_staging.yml`)
- **Triggers**: Pushes to the `develop` branch (after tests pass)
- **Target**: staging.resilienceatlas.org
- **Features**: Deploys directly to EC2 instance using Docker Compose
- **Environment**: Uses staging-specific environment variables and secrets
- **Database Refresh**: Automatically copies production database to staging before deployment

#### Production Deployment (`ec2_deploy_production.yml`)
- **Triggers**: Pushes to the `main` branch (after all tests pass)
- **Target**: resilienceatlas.org
- **Features**: Deploys directly to EC2 instance using Docker Compose
- **Environment**: Uses production-specific environment variables and secrets

Key deployment features:
- Direct EC2 deployment using Docker Compose
- Application Load Balancer for traffic routing
- Just-in-time SSH access during deployment
- Automatic database refresh for staging environment
- Health checks and rollback capabilities
- AWS Secrets Manager for secure credential management
- Deployment only proceeds after all relevant tests pass
- **Staging database refresh**: Production data automatically copied to staging for realistic testing

### TiTiler COGs Workflows

The TiTiler COGs service has dedicated workflows for AWS Lambda deployment:

#### TiTiler COGs Deployment (`titiler_cogs_deployment.yaml`)

- **Feature Branch Deployment**: Automatically deploys feature branches to isolated AWS stacks for testing
- **Production Deployment**: Deploys master branch to production stack
- **Manual Deployment**: Supports workflow dispatch for manual deployments
- **Triggers**: Runs on pushes to `cloud_functions/titiler_cogs/` directory

Key features:
- Uses AWS SAM CLI for serverless application deployment
- Creates isolated stacks for each feature branch with unique FQDNs
- Container-based builds for consistent environments
- Role-based AWS authentication for secure deployments
- Supports custom domain names via Route53

#### TiTiler COGs Cleanup (`titiler_cogs_cleanup.yaml`)

- **Automatic Cleanup**: Removes AWS stacks when feature branches are deleted
- **Manual Cleanup**: Supports workflow dispatch for manual stack deletion
- **Cost Optimization**: Prevents accumulation of unused AWS resources

The TiTiler COGs service provides dynamic tile generation for Cloud Optimized GeoTIFFs (COGs) and is deployed as AWS Lambda functions behind API Gateway. See [cloud_functions/titiler_cogs/README.md](cloud_functions/titiler_cogs/README.md) for detailed deployment and usage instructions.

## Production Deployment

### AWS EC2 Deployment

The application is deployed directly to AWS EC2 instances using Docker Compose for both staging and production environments:

- **Staging**: [staging.resilienceatlas.org](https://staging.resilienceatlas.org) (deployed from `develop` branch)
- **Production**: [resilienceatlas.org](https://resilienceatlas.org) (deployed from `main` branch)

#### Deployment Architecture

- **Hosting**: EC2 instances running Docker Compose
- **Load Balancing**: Application Load Balancer for traffic distribution and SSL termination
- **Secret Management**: Environment variables and AWS Secrets Manager for secure configuration
- **SSH Access**: Just-in-time SSH access during deployments for security
- **Monitoring**: CloudWatch logs and instance metrics

#### Setting Up EC2 Deployment

1. **Prerequisites**: AWS account with appropriate IAM permissions, Python 3.8+, AWS CLI configured

2. **Infrastructure Setup**:
   ```bash
   cd scripts
   pip install -r requirements.txt
   ./setup_complete_infrastructure.sh
   ```

3. **Configure GitHub Actions**: Set up repository secrets for automatic deployments

4. **Environment Configuration**: Update environment files and AWS secrets with real values

See [scripts/README.md](scripts/README.md) for detailed setup instructions and script documentation.

## Docker Setup

The project includes Docker configuration for easy development and deployment. There are three Docker Compose configurations:

- `docker-compose.yml` - Production setup (frontend + backend only)
- `docker-compose.dev.yml` - Development setup (includes PostgreSQL database)
- `docker-compose.test.yml` - Test environment for running automated tests

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Quick Start

1. **Clone the repository and navigate to the project root**

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration values
   ```

3. **For development (includes database):**
   ```bash
   docker compose -f docker-compose.dev.yml up --build
   ```
   
   This will start:
   - PostgreSQL database on port 5432
   - Backend API on http://localhost:3001
   - Frontend application on http://localhost:3000

4. **For production:**
   ```bash
   docker compose up --build
   ```
   
   This will start:
   - Backend API on http://localhost:3001
   - Frontend application on http://localhost:3000
   
   Note: For production, you need to provide your own PostgreSQL database via the `DATABASE_URL` environment variable.

### Running Tests

#### Backend Tests (RSpec)
```bash
# Run all backend tests (linting, security, unit tests - excludes system tests by default)
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test

# Run all tests including system tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec

# Run specific test commands
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test security
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test audit

# Run specific test file
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test rspec spec/models/user_spec.rb

# Show all available commands
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test help
```

#### Frontend Tests (ESLint/TypeScript/Prettier)
```bash
# Run all frontend checks (linting, type-check, prettier, build)
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test

# Run specific test commands
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test lint
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test type-check
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test prettier
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test build

# Run Cypress e2e tests (requires backend services)
docker compose -f docker-compose.test.yml run --rm frontend-test ./bin/test cypress

# Show all available commands
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test help
```

#### System Tests (Browser-based)
System tests use Capybara with Chrome to test the admin interface and user interactions:

```bash
# Run system tests only (with Chrome verification)
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test system

# Run system tests (skip Chrome verification)
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test system-force

# Verify Chrome setup for system tests
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test verify-chrome

# Run specific system test file
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test system spec/systems/admin/auth_spec.rb
```

System tests cover:
- Admin authentication and authorization
- CRUD operations for all admin models (layers, indicators, journeys, etc.)
- File uploads and data management
- User interface interactions
- Browser-based workflows

**Note**: System tests require Chrome and Xvfb for headless browser testing. They are excluded from the default test run due to longer execution time.

#### Integration Tests (Full E2E)
```bash
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

### Fixing Linting Issues

The project uses ESLint and RuboCop for code quality enforcement. Common issues and their fixes:

#### Backend (RuboCop)
```bash
# Auto-fix most RuboCop issues
docker compose -f docker-compose.test.yml run --rm backend-test bash -c "bundle exec rubocop -A"

# Run specific checks
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test lint
```

#### Frontend (ESLint)
Common ESLint warnings and fixes:

1. **Console statements**: Add `// eslint-disable-next-line no-console` before console statements in development code
2. **Unused variables**: Remove unused imports and variables, or prefix with underscore if needed for interface compliance
3. **React Hook dependencies**: Add missing dependencies to useEffect, useCallback, and useMemo dependency arrays
4. **TypeScript any types**: Add `// eslint-disable-next-line @typescript-eslint/no-explicit
