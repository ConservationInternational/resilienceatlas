# ResilienceAtlas EC2 Deployment with AWS CodeDeploy

This directory contains scripts and configuration for deploying ResilienceAtlas to AWS EC2 instances using Docker Compose and AWS CodeDeploy.

## Overview

The deployment architecture uses:
- **Single EC2 Instance** for hosting both staging and production (cost-effective)
- **AWS CodeDeploy** for automated deployments from GitHub
- **Application Load Balancer** for routing traffic based on domain names
- **Docker Compose** for container orchestration
- **GitHub Actions** for CI/CD pipeline
- **S3** for storing deployment packages
- **Route53** for DNS management

## Single-Instance Architecture

Both staging and production run on the **same EC2 instance** with isolated:
- **Directories**: `/opt/resilienceatlas-staging`, `/opt/resilienceatlas-production`
- **Ports**: Staging (3000/3001/5432), Production (4000/4001)
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
   
   # Step 2: Create EC2 instance role for CodeDeploy
   python3 setup_ec2_instance_role.py
   
   # Step 3: Create S3 bucket for deployments
   python3 setup_s3_bucket.py
   
   # Step 4: Create CodeDeploy application and deployment groups
   python3 setup_codedeploy.py
   
   # Step 5: Set up Application Load Balancer (optional, if not using existing)
   python3 setup_alb.py <vpc-id>
   ```

3. **On the EC2 instance, install the CodeDeploy agent:**
   ```bash
   sudo bash scripts/install-codedeploy-agent.sh
   ```

4. **Tag your EC2 instance:**
   - Required tag: `Project=ResilienceAtlas`
   - (No Environment tag needed - both environments run on same instance)

5. **Configure GitHub Actions secrets** (see below)

## Scripts Reference

### Infrastructure Setup Scripts

| Script | Description |
|--------|-------------|
| `setup_github_oidc.py` | Creates GitHub OIDC provider and IAM role for secure authentication |
| `setup_ec2_instance_role.py` | Creates IAM role for EC2 instances with CodeDeploy access |
| `setup_s3_bucket.py` | Creates S3 bucket for deployment packages |
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

```bash
# AWS OIDC Authentication (no access keys needed!)
AWS_OIDC_ROLE_ARN          # IAM role ARN from setup_github_oidc.py
DEPLOYMENT_S3_BUCKET       # S3 bucket name from setup_s3_bucket.py

# Staging Environment
STAGING_DB_PASSWORD        # Postgres password for staging container
STAGING_SECRET_KEY_BASE    # Rails secret key (128 chars)
STAGING_DEVISE_KEY         # Devise authentication key

# Production Environment  
PRODUCTION_DATABASE_URL    # postgresql://user:pass@host:port/db
PRODUCTION_SECRET_KEY_BASE # Rails secret key (128 chars)
PRODUCTION_DEVISE_KEY      # Devise authentication key

# Application Configuration
NEXT_PUBLIC_GOOGLE_ANALYTICS  # Google Analytics ID
NEXT_PUBLIC_TRANSIFEX_TOKEN   # Transifex API token
NEXT_PUBLIC_TRANSIFEX_SECRET  # Transifex secret
NEXT_PUBLIC_GOOGLE_API_KEY    # Google Maps API key
RESILIENCE_API_KEY            # Resilience API key
SPARKPOST_API_KEY             # SparkPost email service key
```

## Deployment Flow

### Staging Deployment

1. **Push to `staging`** triggers GitHub Actions workflow
2. **Create deployment package** (zip archive of repository)
3. **Upload to S3** in staging folder
4. **Create CodeDeploy deployment**
5. **CodeDeploy agent** on staging instance:
   - Stops existing frontend/backend containers
   - Downloads deployment package from S3
   - Builds new Docker images
   - Syncs production database (if enabled)
   - Starts new containers
   - Runs database migrations
   - Performs health checks

### Production Deployment

1. **Push to `main`** triggers GitHub Actions workflow
2. **Create deployment package** (zip archive of repository)
3. **Upload to S3** in production folder
4. **Create CodeDeploy deployment**
5. **CodeDeploy agent** on production instance:
   - Stops existing containers
   - Downloads deployment package from S3
   - Builds new Docker images
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
docker compose -f docker-compose.staging.yml down

# Checkout previous version (from backup .sha file)
git checkout <previous-commit>

# Rebuild and restart
docker compose -f docker-compose.staging.yml up -d --build
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
sudo tail -f /opt/codedeploy-agent/deployment-root/*/logs/scripts.log
```

### View Application Logs
```bash
ssh ubuntu@<instance-ip>
cd /opt/resilienceatlas

# All container logs
docker compose -f docker-compose.staging.yml logs

# Specific container
docker compose -f docker-compose.staging.yml logs frontend
docker compose -f docker-compose.staging.yml logs backend
docker compose -f docker-compose.staging.yml logs database
```

### Health Check Commands
```bash
# Frontend
curl -f http://localhost:3000

# Backend
curl -f http://localhost:3001/health

# Database (staging only)
docker compose -f docker-compose.staging.yml exec database pg_isready -U postgres
```

### Common Issues

1. **Deployment fails at ApplicationStop**
   - Check if Docker is running: `sudo systemctl status docker`
   - Check container status: `docker ps -a`

2. **Deployment fails at AfterInstall (build)**
   - Check disk space: `df -h`
   - Check Docker build logs in script output
   - Ensure all required build arguments are available

3. **Deployment fails at ValidateService**
   - Check container logs for startup errors
   - Verify database connectivity
   - Check environment variables are set correctly

4. **Database sync fails**
   - Verify `PRODUCTION_DATABASE_URL` is correct
   - Check network connectivity to production database
   - Ensure PostgreSQL client is installed

## Security Considerations

- **S3 bucket** is private with encryption enabled
- **IAM policies** follow principle of least privilege
- **Security groups** restrict access to necessary ports only
- **Secrets** are stored in GitHub Secrets, not in code
- **Database credentials** are never logged
- **SSL/TLS** for all external traffic via ALB

## Cost Optimization

- **S3 lifecycle rules** automatically clean up old deployment packages
- **Staging**: 30-day retention for deployment packages
- **Production**: 90-day retention for deployment packages
- Consider using **Spot Instances** for staging
- Use **Reserved Instances** for production to reduce costs
