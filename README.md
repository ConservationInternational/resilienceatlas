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

The project uses GitHub Actions for continuous integration and deployment. The CI/CD workflows are organized into three main categories:

### Frontend CI/CD

The frontend CI/CD pipeline (`frontend_ci_cd.yml`) includes:

- **Testing**: End-to-end tests using Cypress on both Chrome and Firefox browsers
- **Deployment**: Automatic deployment using Capistrano to staging (develop branch) and production (master branch)
- **Triggers**: Runs on pushes to the `frontend/` directory or workflow file changes

Key features:
- Runs tests in parallel on multiple browsers
- Uses Node.js version specified in `.nvmrc`
- Caches yarn dependencies for faster builds
- Uploads test screenshots on failure for debugging
- Environment-based deployments (staging for develop, production for master)

### Backend CI/CD

The backend CI/CD pipeline (`backend_ci_cd.yml`) includes:

- **Testing**: RSpec test suite with PostgreSQL database
- **Linting**: RuboCop code style checks
- **Security**: Brakeman security analysis and Bundle Audit for dependency vulnerabilities
- **Deployment**: Automatic deployment using Capistrano to staging and production environments
- **Triggers**: Runs on pushes to the `backend/` directory or workflow file changes

Key features:
- Uses PostGIS-enabled PostgreSQL for testing
- Parallel execution of tests, linting, and security checks
- Ruby version management with bundler caching
- Comprehensive security scanning

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
docker-compose -f docker-compose.test.yml run backend-test
```

#### Frontend Tests (Cypress)
```bash
docker-compose -f docker-compose.test.yml run frontend-test
```

#### Run All Tests
```bash
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
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
