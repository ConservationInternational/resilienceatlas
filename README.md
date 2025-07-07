# Resilience Atlas

## Architecture

This repository contains all the code and documentation necessary to set up and deploy the project. It is organised in 4 main subdirectories, with accompanying documentation inside each.

| Subdirectory name | Description                                                 | Documentation                                          |
|-------------------|-------------------------------------------------------------|--------------------------------------------------------|
| frontend          | Frontend application                                        | [frontend/README.md](frontend/README.md)               |
| backend           | The Ruby on Rails backend application (API + backoffice)    | [backend/README.md](backend/README.md)                 |
| cloud_functions   | cloud functions code folder                                 | [cloud_functions/README.md](cloud_functions/README.md) |
| infrastructure    | The Terraform project for TiTiler COG tiler as AWS lambda   | [infrastructure/README.md](infrastructure/README.md)   |
| data              | data folder where diverse scripts for data management lives | [data/README.md](data/README.md)                       |

## CI/CD Process

The project uses GitHub Actions for continuous integration and deployment. The CI/CD workflows are organized into comprehensive testing and deployment categories:

### Testing Workflows

The project implements comprehensive testing with Docker-based workflows:

#### Backend Tests (`backend_tests.yml`)
- **Testing**: RSpec test suite with PostgreSQL database
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
- Comprehensive test reporting with JUnit integration
- Test artifacts collection (screenshots, videos on failure)
- Health checks and service dependency management

See [.github/TESTING.md](.github/TESTING.md) for detailed testing documentation.

### ECS Deployment Workflows

The project uses AWS ECS (Elastic Container Service) for deployment with separate workflows for staging and production:

#### Staging Deployment (`ecs_deploy_staging.yml`)
- **Triggers**: Pushes to the `develop` branch (after tests pass)
- **Target**: staging.resilienceatlas.org
- **Features**: Builds and deploys both frontend and backend containers to ECS
- **Environment**: Uses staging-specific environment variables and secrets
- **Database Refresh**: Automatically copies production database to staging before deployment

#### Production Deployment (`ecs_deploy_production.yml`)
- **Triggers**: Pushes to the `main` branch (after all tests pass)
- **Target**: resilienceatlas.org
- **Features**: Builds and deploys both frontend and backend containers to ECS
- **Environment**: Uses production-specific environment variables and secrets

Key deployment features:
- Containerized deployment using Docker multi-stage builds
- AWS ECR for container image storage
- ECS with EC2-based cluster for container orchestration
- Application Load Balancers for traffic distribution
- AWS Secrets Manager for secure credential management
- Automatic health checks and service stability verification
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

### AWS ECS Deployment

The application is deployed to AWS ECS (Elastic Container Service) using EC2-based clusters for both staging and production environments:

- **Staging**: [staging.resilienceatlas.org](https://staging.resilienceatlas.org) (deployed from `develop` branch)
- **Production**: [resilienceatlas.org](https://resilienceatlas.org) (deployed from `master`/`main` branch)

#### Deployment Architecture

- **Container Registry**: AWS ECR for storing Docker images
- **Orchestration**: AWS ECS with EC2 cluster (`resilienceatlas-cluster`)
- **Load Balancing**: Application Load Balancers for traffic distribution
- **Secret Management**: AWS Secrets Manager for secure credential storage
- **Monitoring**: CloudWatch logs and ECS service metrics

#### Setting Up ECS Deployment

1. **Prerequisites**: AWS account with appropriate IAM permissions, Python 3.7+, AWS CLI configured

2. **Infrastructure Setup**:
   ```bash
   cd scripts
   pip install -r requirements.txt
   python setup_ecs_infrastructure.py --account-id YOUR_AWS_ACCOUNT_ID
   ```

3. **Services Creation**:
   ```bash
   python create_ecs_services.py --account-id YOUR_AWS_ACCOUNT_ID
   ```

4. **Configure Secrets**: Update AWS Secrets Manager entries with real database URLs and application secrets

5. **GitHub Actions**: Configure repository secrets for automatic deployments

See [DOCKER.md](DOCKER.md) for detailed setup instructions and [scripts/README.md](scripts/README.md) for script documentation.

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
   docker-compose -f docker-compose.dev.yml up --build
   ```
   
   This will start:
   - PostgreSQL database on port 5432
   - Backend API on http://localhost:3001
   - Frontend application on http://localhost:3000

4. **For production:**
   ```bash
   docker-compose up --build
   ```
   
   This will start:
   - Backend API on http://localhost:3001
   - Frontend application on http://localhost:3000
   
   Note: For production, you need to provide your own PostgreSQL database via the `DATABASE_URL` environment variable.

### Running Tests

#### Backend Tests (RSpec)
```bash
# Run all backend tests (linting, security, unit tests)
docker compose -f docker-compose.test.yml run --rm backend-test ./bin/test

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

#### Frontend Tests (Jest/ESLint/TypeScript)
```bash
# Run all frontend tests (linting, type-check, unit tests, build)
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test

# Run specific test commands
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test jest
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test lint
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test type-check
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test build

# Run tests with coverage
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test coverage

# Run tests in watch mode (for development)
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test watch

# Show all available commands
docker compose -f docker-compose.test.yml run --rm --no-deps frontend-test ./bin/test help
```

#### Integration Tests (Full E2E)
```bash
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

### Development Workflow

When developing with Docker:

1. **Start the development environment:**
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

2. **The development setup includes hot reloading:**
   - Frontend: Changes to files in `frontend/` will trigger automatic rebuilds
   - Backend: Changes to files in `backend/` will restart the Rails server

3. **Access the applications:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:3001
   - Database: localhost:5432 (postgres/postgres)

4. **Run commands in containers:**
   ```bash
   # Backend commands
   docker-compose -f docker-compose.dev.yml exec backend bundle exec rails console
   docker-compose -f docker-compose.dev.yml exec backend bundle exec rails db:migrate
   
   # Frontend commands
   docker-compose -f docker-compose.dev.yml exec frontend yarn add package-name
   docker-compose -f docker-compose.dev.yml exec frontend yarn lint
   ```

5. **Stop the environment:**
   ```bash
   docker-compose -f docker-compose.dev.yml down
   ```

6. **Clean up (remove volumes):**
   ```bash
   docker-compose -f docker-compose.dev.yml down -v
   ```

### Environment Variables

The Docker setup uses environment variables from `.env` file in the project root. Copy `.env.example` to `.env` and configure:

#### Backend Variables
- `DATABASE_URL` - PostgreSQL connection string (production only)
- `SECRET_KEY_BASE` - Rails secret key
- `DEVISE_KEY` - Devise authentication key
- `BACKEND_URL` - Backend URL for CORS configuration
- `FRONTEND_URL` - Frontend URL for CORS configuration

#### Frontend Variables
- `NEXT_PUBLIC_API_HOST` - Backend API URL
- `NEXT_PUBLIC_GOOGLE_ANALYTICS` - Google Analytics ID
- `NEXT_PUBLIC_TRANSIFEX_TOKEN` - Transifex token for translations
- `NEXT_PUBLIC_TRANSIFEX_SECRET` - Transifex secret
- `NEXT_PUBLIC_GOOGLE_API_KEY` - Google API key

### Troubleshooting

#### Common Issues

1. **Port conflicts**: If ports 3000, 3001, or 5432 are in use, modify the port mappings in the docker-compose files.

2. **Permission issues**: On Linux/macOS, you might need to fix file permissions:
   ```bash
   sudo chown -R $USER:$USER .
   ```

3. **Database connection issues**: Ensure the database container is fully started before the backend connects:
   ```bash
   docker-compose -f docker-compose.dev.yml logs db
   ```

4. **Git SSH authentication issues**: If you get "Host key verification failed" errors when installing frontend dependencies:
   ```bash
   # Stop containers if running
   docker-compose -f docker-compose.dev.yml down
   
   # Remove the problematic yarn.lock file
   rm frontend/yarn.lock
   
   # Clear Docker cache and rebuild
   docker-compose -f docker-compose.dev.yml build --no-cache
   docker-compose -f docker-compose.dev.yml up
   ```
   
   Alternatively, you can configure git to use HTTPS instead of SSH by running:
   ```bash
   docker-compose -f docker-compose.dev.yml run frontend git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
   docker-compose -f docker-compose.dev.yml run frontend yarn install
   ```

5. **Cypress/Xvfb missing dependency errors**: If you get "Your system is missing the dependency: Xvfb" errors during frontend startup:
   
   This happens because Cypress tries to verify its installation. The development environment is configured to skip Cypress binary installation via `CYPRESS_INSTALL_BINARY=0`. If you still encounter this issue:
   ```bash
   # Stop containers and clear cache
   docker-compose -f docker-compose.dev.yml down -v
   docker-compose -f docker-compose.dev.yml build --no-cache
   docker-compose -f docker-compose.dev.yml up
   ```

6. **Clear cache and rebuild**:
   ```bash
   docker-compose -f docker-compose.dev.yml down -v
   docker-compose -f docker-compose.dev.yml build --no-cache
   docker-compose -f docker-compose.dev.yml up
   ```
