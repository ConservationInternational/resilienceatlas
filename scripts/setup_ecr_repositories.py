#!/usr/bin/env python3
"""
ECR Repository Setup Script

This script creates and configures the ECR repositories needed for the
ResilienceAtlas deployment optimization strategy.

Requirements:
  - AWS CLI configured with appropriate credentials
  - boto3 Python package: pip install boto3

Usage:
  python scripts/setup_ecr_repositories.py [--region us-east-1] [--dry-run]
"""

import argparse
import sys
import json
import boto3
from botocore.exceptions import ClientError


def create_ecr_repository(ecr_client, repository_name, dry_run=False):
    """
    Create an ECR repository with recommended settings.
    
    Args:
        ecr_client: boto3 ECR client
        repository_name: Name of the repository to create
        dry_run: If True, only print what would be done
        
    Returns:
        bool: True if successful, False otherwise
    """
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Creating repository: {repository_name}")
    
    if dry_run:
        print(f"  Would create repository with:")
        print(f"    - Image scanning on push: enabled")
        print(f"    - Image tag mutability: MUTABLE")
        print(f"    - Lifecycle policy: Keep last 10 images per environment")
        return True
    
    try:
        # Check if repository exists
        try:
            response = ecr_client.describe_repositories(
                repositoryNames=[repository_name]
            )
            print(f"  ✓ Repository already exists")
            return True
        except ClientError as e:
            if e.response['Error']['Code'] != 'RepositoryNotFoundException':
                raise
        
        # Create repository
        response = ecr_client.create_repository(
            repositoryName=repository_name,
            imageScanningConfiguration={'scanOnPush': True},
            imageTagMutability='MUTABLE',
            encryptionConfiguration={'encryptionType': 'AES256'}
        )
        
        print(f"  ✓ Created repository: {response['repository']['repositoryUri']}")
        
        # Set lifecycle policy to prevent unbounded image growth
        lifecycle_policy = {
            "rules": [
                {
                    "rulePriority": 1,
                    "description": "Keep last 10 staging images",
                    "selection": {
                        "tagStatus": "tagged",
                        "tagPrefixList": ["staging-"],
                        "countType": "imageCountMoreThan",
                        "countNumber": 10
                    },
                    "action": {"type": "expire"}
                },
                {
                    "rulePriority": 2,
                    "description": "Keep last 10 production images",
                    "selection": {
                        "tagStatus": "tagged",
                        "tagPrefixList": ["production-"],
                        "countType": "imageCountMoreThan",
                        "countNumber": 10
                    },
                    "action": {"type": "expire"}
                },
                {
                    "rulePriority": 3,
                    "description": "Remove untagged images after 7 days",
                    "selection": {
                        "tagStatus": "untagged",
                        "countType": "sinceImagePushed",
                        "countUnit": "days",
                        "countNumber": 7
                    },
                    "action": {"type": "expire"}
                }
            ]
        }
        
        ecr_client.put_lifecycle_policy(
            repositoryName=repository_name,
            lifecyclePolicyText=json.dumps(lifecycle_policy)
        )
        
        print(f"  ✓ Set lifecycle policy")
        
        return True
        
    except ClientError as e:
        print(f"  ✗ Failed to create repository: {e}")
        return False


def setup_ecr_permissions(ecr_client, repository_name, account_id, dry_run=False):
    """
    Set up repository permissions to allow GitHub Actions access.
    
    Args:
        ecr_client: boto3 ECR client
        repository_name: Name of the repository
        account_id: AWS account ID
        dry_run: If True, only print what would be done
        
    Returns:
        bool: True if successful, False otherwise
    """
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Setting permissions for: {repository_name}")
    
    if dry_run:
        print(f"  Would set repository policy to allow:")
        print(f"    - GitHub Actions to push images")
        print(f"    - EC2 instances to pull images")
        return True
    
    try:
        # Repository policy allowing GitHub Actions (via OIDC role) and EC2 to access
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "AllowPushPull",
                    "Effect": "Allow",
                    "Principal": {
                        "AWS": f"arn:aws:iam::{account_id}:root"
                    },
                    "Action": [
                        "ecr:GetDownloadUrlForLayer",
                        "ecr:BatchGetImage",
                        "ecr:BatchCheckLayerAvailability",
                        "ecr:PutImage",
                        "ecr:InitiateLayerUpload",
                        "ecr:UploadLayerPart",
                        "ecr:CompleteLayerUpload"
                    ]
                }
            ]
        }
        
        ecr_client.set_repository_policy(
            repositoryName=repository_name,
            policyText=json.dumps(policy)
        )
        
        print(f"  ✓ Set repository policy")
        return True
        
    except ClientError as e:
        print(f"  ✗ Failed to set permissions: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Setup ECR repositories for ResilienceAtlas'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    
    args = parser.parse_args()
    
    print(f"{'='*70}")
    print(f"ECR Repository Setup for ResilienceAtlas")
    print(f"Region: {args.region}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    print(f"{'='*70}")
    
    # Initialize AWS clients
    try:
        session = boto3.Session()
        ecr_client = session.client('ecr', region_name=args.region)
        sts_client = session.client('sts')
        
        # Get account ID
        account_id = sts_client.get_caller_identity()['Account']
        print(f"\nAWS Account ID: {account_id}")
        
    except Exception as e:
        print(f"\n✗ Failed to initialize AWS clients: {e}")
        print("Make sure AWS CLI is configured with valid credentials")
        sys.exit(1)
    
    # List of repositories to create
    repositories = [
        'resilienceatlas/backend',
        'resilienceatlas/frontend'
    ]
    
    # Create repositories
    success_count = 0
    for repo in repositories:
        if create_ecr_repository(ecr_client, repo, args.dry_run):
            if setup_ecr_permissions(ecr_client, repo, account_id, args.dry_run):
                success_count += 1
    
    # Print summary
    print(f"\n{'='*70}")
    print(f"Summary: {success_count}/{len(repositories)} repositories configured")
    
    if args.dry_run:
        print("\nThis was a DRY RUN. Run without --dry-run to apply changes.")
    else:
        print("\n✓ Setup complete!")
        print("\nNext steps:")
        print("1. Verify GitHub Actions has AWS_OIDC_ROLE_ARN secret configured")
        print("2. Deploy to staging to test ECR image builds")
        print("3. Monitor first deployment to ensure images are pushed/pulled correctly")
        print("\nECR Repository URIs:")
        for repo in repositories:
            print(f"  {account_id}.dkr.ecr.{args.region}.amazonaws.com/{repo}")
    
    print(f"{'='*70}")
    
    sys.exit(0 if success_count == len(repositories) else 1)


if __name__ == '__main__':
    main()
