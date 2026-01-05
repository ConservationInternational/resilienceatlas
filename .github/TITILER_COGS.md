# TiTiler COGs Service

## Overview

TiTiler is a dynamic tile server that provides on-the-fly rendering of Cloud Optimized GeoTIFFs (COGs). In the Resilience Atlas project, TiTiler enables:

- **Dynamic tile generation**: Renders map tiles from COG files stored in S3 without pre-generating tile pyramids
- **Efficient data access**: COGs allow range requests, so only the needed portions of large raster files are read
- **Flexible visualization**: Supports dynamic rescaling, color mapping, and band combinations
- **Serverless architecture**: Deployed as AWS Lambda functions for automatic scaling and cost efficiency

The service is deployed behind API Gateway and provides endpoints for:
- Tile requests (`/tiles/{z}/{x}/{y}`)
- Metadata and statistics
- Preview images
- Point queries

## CI/CD Workflows

### TiTiler COGs Deployment (`titiler_cogs_deployment.yaml`)

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

### TiTiler COGs Cleanup (`titiler_cogs_cleanup.yaml`)

- **Automatic Cleanup**: Removes AWS stacks when feature branches are deleted
- **Manual Cleanup**: Supports workflow dispatch for manual stack deletion
- **Cost Optimization**: Prevents accumulation of unused AWS resources

## Deployment

See [cloud_functions/titiler_cogs/README.md](../cloud_functions/titiler_cogs/README.md) for detailed deployment and usage instructions.
