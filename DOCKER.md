# Docker & AWS ECS Deployment Guide

This is a comprehensive guide for Docker setup and AWS ECS deployment of Resilience Atlas.

## Local Development with Docker

### Files Created

- `backend/Dockerfile` - Backend container configuration
- `frontend/Dockerfile` - Frontend container configuration (already existed, optimized for production)
- `docker-compose.yml` - Production setup (frontend + backend)
- `docker-compose.dev.yml` - Development setup (includes PostgreSQL)
- `docker-compose.test.yml` - Test environment
- `.env.example` - Environment variables template
- `docker.sh` / `docker.bat` - Helper scripts for common operations

## Quick Commands

### Setup (First Time)
```bash
# Copy environment files
./docker.sh setup  # or docker.bat setup on Windows

# Edit .env files with your configuration
# Then start development environment
./docker.sh dev    # or docker.bat dev on Windows
```

### Development
```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up

# Start in background
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop
docker-compose -f docker-compose.dev.yml down
```

### Production
```bash
# Start production environment
docker-compose up

# Start in background
docker-compose up -d
```

### Testing
```bash
# Run all tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Run backend tests only
docker-compose -f docker-compose.test.yml run --rm backend-test

# Run frontend tests only
docker-compose -f docker-compose.test.yml run --rm frontend-test
```

### Cleanup
```bash
# Stop all containers
docker-compose -f docker-compose.dev.yml down
docker-compose down
docker-compose -f docker-compose.test.yml down

# Remove volumes (clean slate)
docker-compose -f docker-compose.dev.yml down -v
```

## Ports

- **Frontend**: http://localhost:3000
- **Backend**: http://localhost:3001
- **PostgreSQL** (dev): localhost:5432
- **PostgreSQL** (test): localhost:5433

## Environment Variables

Key environment variables to configure in `.env`:

### Backend
- `DATABASE_URL` - PostgreSQL connection (production only)
- `SECRET_KEY_BASE` - Rails secret key
- `DEVISE_KEY` - Authentication key
- `BACKEND_URL` / `FRONTEND_URL` - For CORS

### Frontend  
- `NEXT_PUBLIC_API_HOST` - Backend API URL
- `NEXT_PUBLIC_GOOGLE_ANALYTICS` - Analytics ID
- Translation service tokens (Transifex)

## Troubleshooting

### Common Issues

1. **Port conflicts**: Change port mappings in docker-compose files
2. **Permission issues**: `sudo chown -R $USER:$USER .` (Linux/macOS)
3. **Database connection**: Check if DB container started properly
4. **Cache issues**: Use `docker-compose build --no-cache`

### Useful Commands

```bash
# Check container status
docker-compose -f docker-compose.dev.yml ps

# Execute commands in running containers
docker-compose -f docker-compose.dev.yml exec backend rails console
docker-compose -f docker-compose.dev.yml exec frontend yarn add package-name

# View container logs
docker-compose -f docker-compose.dev.yml logs backend
docker-compose -f docker-compose.dev.yml logs frontend

# Rebuild specific service
docker-compose -f docker-compose.dev.yml build backend
docker-compose -f docker-compose.dev.yml up backend
```

## AWS ECS Production Deployment

The production deployment uses AWS ECS (Elastic Container Service) with an EC2-based cluster for both staging and production environments.

### Architecture Overview

- **Staging Environment**: staging.resilienceatlas.org
- **Production Environment**: resilienceatlas.org
- **Shared ECS Cluster**: `resilienceatlas-cluster`
- **Container Registry**: AWS ECR
- **Load Balancing**: Application Load Balancers (ALB)
- **Secret Management**: AWS Secrets Manager
- **Database Refresh**: Automated production-to-staging database copying

### Staging Database Strategy

The staging environment uses a **containerized PostgreSQL database** that runs as a sidecar container in ECS. This approach provides:

- **Isolation**: Staging database is completely separate from production
- **Cost Efficiency**: No separate RDS instance required for staging
- **Fresh Data**: Database is rebuilt with production data on each deployment
- **PostGIS Support**: Full PostGIS extensions available

### Database Refresh Process

The staging deployment automatically refreshes the staging database with production data:

1. **Production Dump**: Creates filtered dump from production RDS
2. **Container Setup**: Starts temporary PostGIS container locally
3. **Data Restore**: Restores production data into container
4. **User Setup**: Creates application user with proper permissions
5. **Image Creation**: Commits container as Docker image
6. **ECR Push**: Pushes database image to ECR
7. **ECS Deployment**: Deploys database container alongside backend

**Excluded Tables for Performance:**
- `action_text_rich_texts` - Large text content
- `active_storage_blobs` - File storage data
- `active_storage_attachments` - File attachments  
- `logs` - Application logs
- `audit_logs` - Audit trail data

**Security Considerations:**
- Database credentials stored as GitHub secrets
- Encrypted database connections
- Temporary dump files immediately cleaned up
- No persistent storage of production data in CI environment

### Prerequisites

1. **AWS Account**: With appropriate IAM permissions
2. **Python 3.7+**: For running setup scripts
3. **AWS CLI**: Configured with credentials
4. **Docker**: For local image building (optional)

### Setup Process

#### 1. Install Python Dependencies

```bash
cd scripts
pip install -r requirements.txt
```

#### 2. Set Up ECS Infrastructure

```bash
python setup_ecs_infrastructure.py --account-id YOUR_AWS_ACCOUNT_ID --region us-east-1
```

This script creates:
- ECR repositories for frontend and backend images
- ECS cluster (`resilienceatlas-cluster`)
- IAM roles for ECS tasks
- CloudWatch log groups
- AWS Secrets Manager entries (with placeholder values)
- Updated task definition files

#### 3. Configure Secrets

Update the following secrets in AWS Secrets Manager with real values:

**Staging Secrets:**
- `resilienceatlas/staging/database-url`
- `resilienceatlas/staging/secret-key-base`
- `resilienceatlas/staging/devise-key`

**Production Secrets:**
- `resilienceatlas/production/database-url`
- `resilienceatlas/production/secret-key-base`
- `resilienceatlas/production/devise-key`

#### 4. Create ECS Services

```bash
python create_ecs_services.py --account-id YOUR_AWS_ACCOUNT_ID --region us-east-1
```

This script creates:
- Security groups for frontend and backend services
- Application Load Balancers for both environments
- Target groups with health checks
- ECS services for staging and production
- ALB listeners and routing rules

#### 5. Configure GitHub Actions Secrets

Add the following secrets to your GitHub repository:

**AWS Credentials:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

**Environment Variables:**
- `STAGING_NEXT_PUBLIC_API_HOST`
- `PRODUCTION_NEXT_PUBLIC_API_HOST`
- `NEXT_PUBLIC_GOOGLE_ANALYTICS`
- `NEXT_PUBLIC_TRANSIFEX_TOKEN`
- `NEXT_PUBLIC_TRANSIFEX_SECRET`
- `NEXT_PUBLIC_GOOGLE_API_KEY`

#### 6. Configure DNS

Point your domains to the ALB DNS names:
- `staging.resilienceatlas.org` → Staging ALB DNS
- `resilienceatlas.org` → Production ALB DNS

### Deployment Workflows

#### Automatic Deployments

- **Staging**: Triggered on pushes to `develop` branch
- **Production**: Triggered on pushes to `master` or `main` branch

#### Manual Deployments

You can trigger deployments manually from the GitHub Actions tab using the "workflow_dispatch" option.

### ECS Services Configuration

#### Frontend Services
- **Image**: Built from `frontend/Dockerfile`
- **Port**: 3000
- **Health Check**: `/api/health`
- **Resources**: 512 CPU, 1024MB RAM (staging) / 1024 CPU, 2048MB RAM (production)

#### Backend Services
- **Image**: Built from `backend/Dockerfile`
- **Port**: 3001
- **Health Check**: `/api/health`
- **Resources**: 1024 CPU, 2048MB RAM (staging) / 2048 CPU, 4096MB RAM (production)

### Monitoring and Logs

#### CloudWatch Logs
- Frontend logs: `/ecs/resilienceatlas-frontend-{env}`
- Backend logs: `/ecs/resilienceatlas-backend-{env}`

#### Health Checks
- ALB health checks configured for both services
- 30-second intervals with 5-second timeout
- Unhealthy threshold: 5 consecutive failures

### Scaling

#### Manual Scaling
```bash
aws ecs update-service \
  --cluster resilienceatlas-cluster \
  --service resilienceatlas-frontend-production \
  --desired-count 3
```

#### Auto Scaling
Configure ECS Service Auto Scaling in the AWS Console for production workloads.

### Troubleshooting

#### Common Issues

1. **Service not starting**: Check CloudWatch logs for container errors
2. **Health check failures**: Verify the `/api/health` endpoint is accessible
3. **Image pull errors**: Ensure ECR repositories exist and contain images
4. **Permission errors**: Verify IAM roles have correct policies attached

#### Useful Commands

```bash
# Check service status
aws ecs describe-services --cluster resilienceatlas-cluster --services resilienceatlas-frontend-production

# View service events
aws ecs describe-services --cluster resilienceatlas-cluster --services resilienceatlas-frontend-production --query 'services[0].events'

# Check task definitions
aws ecs list-task-definitions --family-prefix resilienceatlas

# View running tasks
aws ecs list-tasks --cluster resilienceatlas-cluster --service-name resilienceatlas-frontend-production

# Get task logs
aws logs get-log-events --log-group-name /ecs/resilienceatlas-frontend-production --log-stream-name STREAM_NAME
```

### Security Considerations

- All secrets stored in AWS Secrets Manager
- ECS tasks run with minimal required permissions
- Security groups restrict access to necessary ports only
- Container images scanned for vulnerabilities in ECR
- HTTPS termination at ALB level (configure SSL certificates)

### Cost Optimization

- Use EC2 cluster for cost-effective container hosting
- Implement auto-scaling to match demand
- Monitor CloudWatch metrics for resource utilization
- Consider using AWS Fargate for variable workloads

### Backup and Disaster Recovery

- Database backups handled separately (RDS automated backups)
- Container images stored in ECR with lifecycle policies
- Infrastructure as code in GitHub repository
- Multi-AZ deployment for high availability
