# ResilienceAtlas EC2 Deployment with AWS CodeDeploy

This directory contains scripts and configuration for deploying ResilienceAtlas to AWS EC2 instances using Docker Compose and AWS CodeDeploy.

## Overview

The deployment architecture uses:
- **Single EC2 Instance** for hosting both staging and production (cost-effective)
- **AWS CodeDeploy** for automated deployments from GitHub
- **Amazon ECR** for pre-built Docker images (fast deployments)
- **Application Load Balancer** for routing traffic based on domain names
- **Docker Compose** for container orchestration
- **GitHub Actions** for CI/CD pipeline with optimized builds
- **S3** for storing deployment packages
- **Route53** for DNS management

## Single-Instance Architecture

Both staging and production run on the **same EC2 instance** with isolated:
- **Directories**: `/opt/resilienceatlas-staging`, `/opt/resilienceatlas-production`
- **Ports**: Staging (3000/3001/5433), Production (4000/4001)
- **Docker Networks**: Separate networks per environment
- **Container Names**: Prefixed with environment name

```
GitHub Repository
    │
    ├─ Push to 'staging' branch
    │       │
    │       ▼
    │   GitHub Actions → S3 → CodeDeploy (staging group)
    │       │
    │       ▼
    │   EC2 Instance: /opt/resilienceatlas-staging
    │       ├─ Frontend Container (port 3000)
    │       ├─ Backend Container (port 3001)
    │       └─ Database Container (port 5432)
    │
    └─ Push to 'main' branch
            │
            ▼
        GitHub Actions → S3 → CodeDeploy (production group)
            │
            ▼
        EC2 Instance: /opt/resilienceatlas-production
            ├─ Frontend Container (port 4000)
            └─ Backend Container (port 4001)
            (Production uses external PostgreSQL)
```

## Quick Setup

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Python 3.8+** with pip
3. **EC2 instance** already running (single instance for both environments)
4. **External PostgreSQL** for production database

### AWS Profile Support

All scripts support the `--profile` (or `-p`) option to use a named profile from `~/.aws/credentials`:

```bash
# Use a specific AWS profile
python3 setup_codedeploy.py --profile resilienceatlas

# Or use the short form
python3 setup_s3_bucket.py -p resilienceatlas
```

Example `~/.aws/credentials` file:
```ini
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...

[resilienceatlas]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

If no profile is specified, the default credentials are used.

### Complete Infrastructure Setup

1. **Install dependencies:**
   ```bash
   cd scripts
   pip install -r requirements.txt
   ```

2. **Run the setup scripts in order:**
   ```bash
   # Step 1: Create GitHub OIDC provider and IAM role (RECOMMENDED)
   python3 setup_github_oidc.py
   
   # Step 2: Create EC2 instance role for CodeDeploy and ECR access
   python3 setup_ec2_instance_role.py
   
   # Step 3: Create S3 bucket for deployments
   python3 setup_s3_bucket.py
   
   # Step 4: Setup ECR permissions for GitHub Actions and EC2
   python3 setup_ecr_permissions.py
   
   # Step 5: Create ECR repositories for Docker images
   python3 setup_ecr_repositories.py --region us-east-1
   
   # Step 6: Create CodeDeploy application and deployment groups
   python3 setup_codedeploy.py
   
   # Step 7: Set up Application Load Balancer (optional, if not using existing)
   python3 setup_alb.py <vpc-id>
   ```

3. **On the EC2 instance, install the CodeDeploy agent:**
   ```bash
   sudo bash scripts/install-codedeploy-agent.sh
   ```

4. **Tag your EC2 instance for deployments:**
   - Required tag: `CodeDeploy=ResilienceAtlas`
   - This tag identifies which instance(s) receive CodeDeploy deployments
   - Other instances can have `Project=ResilienceAtlas` without receiving deployments

5. **Configure GitHub Actions secrets** (see below)

## Scripts Reference

### Infrastructure Setup Scripts

| Script | Description |
|--------|-------------|
| `setup_github_oidc.py` | Creates GitHub OIDC provider and IAM role for secure authentication |
| `setup_ec2_instance_role.py` | Creates IAM role for EC2 instances with CodeDeploy and ECR access |
| `setup_s3_bucket.py` | Creates S3 bucket for deployment packages |
| `setup_ecr_permissions.py` | Adds ECR permissions to GitHub Actions OIDC and EC2 instance roles |
| `setup_ecr_repositories.py` | Creates ECR repositories with lifecycle policies for Docker images |
| `setup_codedeploy.py` | Creates CodeDeploy application and deployment groups |
| `setup_alb.py` | Creates Application Load Balancer and target groups |
| `install-codedeploy-agent.sh` | Installs CodeDeploy agent on EC2 instances |

### CodeDeploy Lifecycle Hook Scripts

Located in `scripts/codedeploy/`:

| Script | Phase | Description |
|--------|-------|-------------|
| `common.sh` | - | Shared functions used by all hooks |
| `application-stop.sh` | ApplicationStop | Stops existing containers gracefully |
| `before-install.sh` | BeforeInstall | Prepares environment, creates directories |
| `after-install.sh` | AfterInstall | Builds Docker images, syncs database (staging) |
| `application-start.sh` | ApplicationStart | Starts containers, runs migrations |
| `validate-service.sh` | ValidateService | Performs health checks |
| `sync-database.sh` | - | Copies production database to staging |

### Data Setup Scripts

| Script | Description |
|--------|-------------|
| `setup_ldn_data.sh` | Canonical LDN setup workflow for development and deployed Docker Swarm environments. Downloads source data, imports geometries, builds dimensions, and seeds the LDN scope and popup statistics. |
| `setup_admin_boundaries.sh` | Imports only the geoBoundaries admin layers into `admin_boundaries`, in either local dev or deployed staging/production. |

#### LDN Data Setup

Use `setup_ldn_data.sh` rather than running the individual LDN rake task or seed directly. The script automatically detects local Docker Compose or the running `resilienceatlas-staging`/`resilienceatlas-production` Swarm stack and performs the complete workflow:

1. Downloads the LDN GeoPackages, key CSVs, methodology statistics CSVs, and geoBoundaries data from S3.
2. Imports the GeoPackages with host-side `ogr2ogr`.
3. Runs `rake ldn:build_dimensions` in the backend container to populate `ra_vector.ldn_dissolved_geometries`.
4. Copies the statistics CSVs into the backend container.
5. Runs `db/data/ldn/seed.rb` to seed the LDN scope and populate `ra_nonspatial.ldn_ecoregion_stats` for map popups.

Deploy the backend image and run its database migrations before running the script. The migration creates `ra_nonspatial.ldn_ecoregion_stats`; the setup script populates it.

From the deployed repository directory on a Swarm host:

```bash
cd /opt/resilienceatlas-staging
./scripts/setup_ldn_data.sh --profile <aws-profile>
```

To reuse files already downloaded into a host directory and leave existing admin boundaries unchanged:

```bash
cd /opt/resilienceatlas-staging
LDN_DATA_DIR=/path/to/ldn-data \
   ./scripts/setup_ldn_data.sh --skip-download --skip-boundaries
```

The directory supplied through `LDN_DATA_DIR` must contain both LDN GeoPackages, both key CSVs, and all methodology summary CSVs. `--skip-download` does not skip geometry import or seeding.

Useful verification commands:

```bash
BACKEND=$(docker ps --filter "name=resilienceatlas-staging_backend" --format "{{.ID}}" | head -1)
docker exec "$BACKEND" bundle exec rake ldn:geometry_status
docker exec "$BACKEND" bundle exec rails runner \
   'puts ActiveRecord::Base.connection.select_rows("SELECT methodology, COUNT(*) FROM ra_nonspatial.ldn_ecoregion_stats GROUP BY methodology ORDER BY methodology").map { |row| row.join(": ") }'
```

### Management Scripts

| Script | Description |
|--------|-------------|
| `manage_ec2_instances.py` | Instance management: status, start, stop, maintenance mode |

## GitHub Actions Workflows

### Staging Deployment (`codedeploy_staging.yml`)
- Triggered on pushes to `staging` branch
- Optionally syncs production database to staging
- Deploys via CodeDeploy to staging instance
- Accessible at `https://staging.resilienceatlas.org`

### Production Deployment (`codedeploy_production.yml`)
- Triggered on pushes to `main` branch
- Deploys via CodeDeploy to production instance
- Uses external PostgreSQL database
- Accessible at `https://resilienceatlas.org`

## GitHub Actions Secrets Configuration

### Required Secrets (Using OIDC - Recommended)

All environment configuration is managed through GitHub Secrets. During deployment, the GitHub Actions workflow generates `.env.staging` or `.env.production` files from these secrets, which are then included in the deployment package. **No manual server configuration is required.**

```bash
# AWS OIDC Authentication (no access keys needed!)
AWS_OIDC_ROLE_ARN          # IAM role ARN from setup_github_oidc.py
DEPLOYMENT_S3_BUCKET       # S3 bucket name from setup_s3_bucket.py

# ECR Configuration (automatically set by workflows)
ECR_REGISTRY               # Set by workflows, no manual config needed
BACKEND_IMAGE              # Set by workflows, no manual config needed
FRONTEND_IMAGE             # Set by workflows, no manual config needed

# Staging Environment
STAGING_DB_PASSWORD        # Postgres password for staging container
STAGING_SECRET_KEY_BASE    # Rails secret key (128 chars) - generate with: rails secret
STAGING_DEVISE_KEY         # Devise authentication key - generate with: rails secret

# Production Environment  
PRODUCTION_DATABASE_URL    # postgresql://user:pass@host:port/db
PRODUCTION_SECRET_KEY_BASE # Rails secret key (128 chars) - generate with: rails secret
PRODUCTION_DEVISE_KEY      # Devise authentication key - generate with: rails secret

# Application Configuration
NEXT_PUBLIC_GOOGLE_ANALYTICS  # Google Analytics ID
NEXT_PUBLIC_TRANSIFEX_TOKEN   # Transifex API token
NEXT_PUBLIC_TRANSIFEX_SECRET  # Transifex secret
NEXT_PUBLIC_GOOGLE_API_KEY    # Google Maps API key
RESILIENCE_API_KEY            # Resilience API key
SPARKPOST_API_KEY             # SparkPost email service key

# Error Tracking (optional)
ROLLBAR_ACCESS_TOKEN             # Rollbar server-side token
NEXT_PUBLIC_ROLLBAR_CLIENT_TOKEN # Rollbar client-side token
```

### How Environment Variables Work

1. **GitHub Secrets** → Stored securely in GitHub repository settings
2. **GitHub Actions** → Generates `.env.{environment}` file with secrets during deployment
3. **Deployment Package** → Env file is included in the zip archive
4. **CodeDeploy** → Extracts package to server, env file is automatically available
5. **Docker Compose** → Loads environment variables when starting containers

This approach ensures:
- ✅ No secrets stored on the server
- ✅ No manual server configuration needed
- ✅ Secrets are rotated by updating GitHub Secrets and redeploying
- ✅ Full audit trail in GitHub Actions logs (secrets are masked)

## Deployment Flow

### Optimized Deployment with ECR Pre-built Images

The deployment process has been optimized to use pre-built Docker images stored in Amazon ECR:

1. **GitHub Actions CI/CD Pipeline:**
   - Builds Docker images for backend and frontend
   - Pushes images to Amazon ECR with tags (commit SHA + environment)
   - Creates deployment package with configuration

2. **Fast Deployment to EC2:**
   - EC2 instance pulls pre-built images from ECR (1-2 minutes)
   - No local Docker builds required (saves 15-25 minutes)
   - Images are cached for even faster subsequent pulls

Staging and production share a Docker daemon on the EC2 host. The
`BeforeInstall`, `AfterInstall`, and `ApplicationStart` hooks use the same
host-level `flock` at `/var/lock/resilienceatlas-deploy.lock` so Docker cleanup
cannot overlap another hook's image pulls. Each hook waits up to 300 seconds,
then fails explicitly if the lock is still occupied. The lock is released
automatically when the hook exits; do not delete the lock file.

Backend and frontend images are pulled sequentially to avoid concurrent
extraction of shared containerd layers. Cleanup must use Docker commands, never
delete files directly from containerd's content or snapshot directories.

Run the Docker-operation regression tests without contacting ECR or modifying
the host Docker daemon:

```bash
docker run --rm -v "$PWD:/app:ro" -w /app ruby:3.4.12-bookworm \
  bash scripts/codedeploy/tests/docker-operations.sh
```

### Staging Deployment

1. **Push to `staging`** triggers GitHub Actions workflow
2. **Build and push Docker images to ECR** (cached layers speed up rebuilds)
3. **Create deployment package** (configuration and scripts only)
4. **Upload to S3** in staging folder
5. **Create CodeDeploy deployment**
6. **CodeDeploy agent** on staging instance:
   - Stops existing frontend/backend containers
   - Downloads deployment package from S3
   - **Pulls pre-built images from ECR** (fast!)
   - Syncs production database (if enabled)
   - Starts new containers
   - Runs database migrations
   - Performs health checks

### Production Deployment

1. **Push to `main`** triggers GitHub Actions workflow
2. **Build and push Docker images to ECR** (cached layers speed up rebuilds)
3. **Create deployment package** (configuration and scripts only)
4. **Upload to S3** in production folder
5. **Create CodeDeploy deployment**
6. **CodeDeploy agent** on production instance:
   - Stops existing containers
   - Downloads deployment package from S3
   - **Pulls pre-built images from ECR** (fast!)
   - Starts new containers
   - Runs database migrations
   - Performs health checks

## Database Management

### Staging Database
- Runs in a Docker container (`postgis/postgis:15-3.3`)
- Can be synced from production during deployment
- Set `SYNC_PRODUCTION_DB=true` to enable sync (default)
- Data persists in Docker volume between deployments

### Production Database
- Uses external PostgreSQL server
- Configure via `PRODUCTION_DATABASE_URL`
- Migrations run automatically during deployment

### Manual Database Sync

To manually sync the staging database from production:

```bash
ssh ubuntu@<staging-ip>
cd /opt/resilienceatlas
PRODUCTION_DATABASE_URL="postgresql://..." ./scripts/codedeploy/sync-database.sh
```

## Rollback Procedures

### Automatic Rollback
CodeDeploy automatically rolls back if:
- Deployment fails
- Health checks fail
- Any lifecycle hook script exits with non-zero code

### Manual Rollback via CodeDeploy Console
1. Go to AWS CodeDeploy console
2. Select the deployment group
3. Choose a previous successful deployment
4. Click "Redeploy"

### Manual Rollback via CLI
```bash
# Get deployment history
aws deploy list-deployments \
  --application-name resilienceatlas \
  --deployment-group-name resilienceatlas-staging

# Redeploy a previous revision
aws deploy create-deployment \
  --application-name resilienceatlas \
  --deployment-group-name resilienceatlas-staging \
  --revision revisionType=S3,s3Location={bucket=...,key=...,bundleType=zip}
```

### Manual Rollback on Instance
```bash
ssh ubuntu@<instance-ip>
cd /opt/resilienceatlas

# Check backup commits
ls -la /opt/resilienceatlas-backups/

# Stop current containers
docker compose -f docker-compose.swarm.staging.yml down

# Checkout previous version (from backup .sha file)
git checkout <previous-commit>

# Rebuild and restart
docker compose -f docker-compose.swarm.staging.yml up -d --build
```

## Monitoring and Troubleshooting

### Check Deployment Status
```bash
# View deployment in AWS Console
aws deploy get-deployment --deployment-id <deployment-id>

# List recent deployments
aws deploy list-deployments \
  --application-name resilienceatlas \
  --deployment-group-name resilienceatlas-staging
```

### View CodeDeploy Agent Logs
```bash
ssh ubuntu@<instance-ip>
sudo tail -f /var/log/aws/codedeploy-agent/codedeploy-agent.log
```

### View Deployment Script Logs
```bash
ssh ubuntu@<instance-ip>
sudo tail -f /opt/codedeploy-agent/deployment-root/<deployment-group-id>/<deployment-id>/logs/scripts.log
```

### View Application Logs
```bash
ssh ubuntu@<instance-ip>
cd /opt/resilienceatlas

# All container logs
docker compose -f docker-compose.swarm.staging.yml logs

# Specific container
docker compose -f docker-compose.swarm.staging.yml logs frontend
docker compose -f docker-compose.swarm.staging.yml logs backend
docker compose -f docker-compose.swarm.staging.yml logs database
```

### Health Check Commands
```bash
# Frontend
curl -f http://localhost:3000

# Backend
curl -f http://localhost:3001/health

# Database (staging only)
docker compose -f docker-compose.swarm.staging.yml exec database pg_isready -U postgres
```

### Tile-safe data imports

CartoDB import/configuration/repair tasks, `ldn:build_dimensions`, layer
restore/upgrade, and the Trends.Earth, thresholds and LDN seeds use the shared
`TileSourceLifecycle`. Upload activation and rollback use it with immutable
processor-generated sources. These changes do not publish contributor drafts.

For standalone rake tasks or seed runners, supply an operator identity and a
trustworthy input-content fingerprint (include SQL/view dependencies and all
data files, not a timestamp):

```bash
docker compose -f docker-compose.dev.yml exec \
  -e TILE_IMPORT_IDENTITY=operator:alice \
  -e TILE_IMPORT_FINGERPRINT=sha256-of-reviewed-input-manifest \
  -e TILE_IMPORT_DRY_RUN=1 backend bundle exec rake cartodb:import_tables
```

Remove `TILE_IMPORT_DRY_RUN=1` to execute. The LDN setup script computes a manifest
fingerprint from its input files and implementation; it accepts the same
environment overrides. It stages **before** host-side `ogr2ogr` writes and passes
one durable run ID through its nested tasks/seeds.

An in-place refresh with previously public tiles stops until **all** recorded
`TileCacheInvalidation` rows are confirmed `completed`. Submit/poll these through
the configured operator/admin invalidation workflow; `submitted` is not
confirmation. Never mark them completed without actual CDN completion evidence.
Then rerun the identical operation/manifest/identity. Without configured
invalidation integration, use an operator handoff; there is no silent fallback.
No previously cached sources means no invalidation barrier.

`TileSourceImport` records preserve the manifest, identity, run ID, source
digests, affected layers, generation changes and invalidation IDs. Failed,
staged and reconciliation-required runs deny affected public sources. Resume a
failed writer with the same manifest; the reconciliation job refuses activation
until that writer has succeeded. An identical completed manifest is a no-op
unless another import changed its source generation. Reconciliation checks local
configuration/vector source existence, not live upstream/CDN health.

The initial policy migration records a cutoff inventory. Where historical
explicit revocations are known, set `TILE_SECURITY_RESTRICTED_LAYER_IDS=12,34`
on the migration runner. The earlier `public_data=false` default contains no
historical revocation provenance; review that ambiguity before migration.
Restores discard imported approval/version state and preserve existing
slug/source restrictions and protected-scope credentials.

### Public tile CDN benchmark

After staging CDN behavior is deployed and a public layer has been approved,
measure its versioned route with 100 tiles. Choose coordinates known to contain
tiles for the layer; for timeline COGs, pass an allowed time variant:

```bash
TILE_BENCHMARK_ZOOM=12 \
TILE_BENCHMARK_START_X=2000 \
TILE_BENCHMARK_START_Y=2000 \
TILE_BENCHMARK_QUERY='time=2024-01-01' \
  ./scripts/benchmark_public_tiles.sh \
  'https://api.staging.resilienceatlas.org/api/public-tiles/123/CURRENT_VERSION'
```

The script warms a 10×10 tile range, checks the same 100 URLs again, and
requires at least 95% CloudFront hits (and corresponding renderer-call
reduction) on the measured pass. It does not deploy or invalidate anything.
