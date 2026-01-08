#!/usr/bin/env python3
"""
S3 Deployment Bucket Setup Script for ResilienceAtlas

This script creates and configures the S3 bucket used to store
deployment packages for CodeDeploy.
"""

import boto3
import json
import sys
from botocore.exceptions import ClientError

def create_clients():
    """Create and return AWS service clients."""
    try:
        return {
            's3': boto3.client('s3'),
            'sts': boto3.client('sts')
        }
    except Exception as e:
        print(f"❌ Error creating AWS clients: {e}")
        sys.exit(1)


def get_account_id(sts_client):
    """Get the current AWS account ID."""
    try:
        return sts_client.get_caller_identity()['Account']
    except ClientError as e:
        print(f"❌ Error getting account ID: {e}")
        sys.exit(1)


def get_region():
    """Get the current AWS region."""
    session = boto3.session.Session()
    return session.region_name or 'us-east-1'


def create_bucket(s3_client, bucket_name, region):
    """Create an S3 bucket."""
    try:
        if region == 'us-east-1':
            s3_client.create_bucket(Bucket=bucket_name)
        else:
            s3_client.create_bucket(
                Bucket=bucket_name,
                CreateBucketConfiguration={'LocationConstraint': region}
            )
        print(f"✅ Created S3 bucket: {bucket_name}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
            print(f"⚠️ S3 bucket already exists: {bucket_name}")
            return True
        elif e.response['Error']['Code'] == 'BucketAlreadyExists':
            print(f"❌ S3 bucket name already taken globally: {bucket_name}")
            return False
        else:
            print(f"❌ Error creating S3 bucket: {e}")
            return False


def enable_versioning(s3_client, bucket_name):
    """Enable versioning on the S3 bucket."""
    try:
        s3_client.put_bucket_versioning(
            Bucket=bucket_name,
            VersioningConfiguration={'Status': 'Enabled'}
        )
        print(f"✅ Enabled versioning on bucket: {bucket_name}")
        return True
    except ClientError as e:
        print(f"❌ Error enabling versioning: {e}")
        return False


def block_public_access(s3_client, bucket_name):
    """Block all public access to the S3 bucket."""
    try:
        s3_client.put_public_access_block(
            Bucket=bucket_name,
            PublicAccessBlockConfiguration={
                'BlockPublicAcls': True,
                'IgnorePublicAcls': True,
                'BlockPublicPolicy': True,
                'RestrictPublicBuckets': True
            }
        )
        print(f"✅ Blocked public access on bucket: {bucket_name}")
        return True
    except ClientError as e:
        print(f"❌ Error blocking public access: {e}")
        return False


def configure_lifecycle_rules(s3_client, bucket_name):
    """Configure lifecycle rules to clean up old deployment packages."""
    lifecycle_config = {
        'Rules': [
            {
                'ID': 'CleanupOldStagingDeployments',
                'Status': 'Enabled',
                'Filter': {'Prefix': 'staging/'},
                'Expiration': {'Days': 30},
                'NoncurrentVersionExpiration': {'NoncurrentDays': 7}
            },
            {
                'ID': 'CleanupOldProductionDeployments',
                'Status': 'Enabled',
                'Filter': {'Prefix': 'production/'},
                'Expiration': {'Days': 90},
                'NoncurrentVersionExpiration': {'NoncurrentDays': 30}
            }
        ]
    }
    
    try:
        s3_client.put_bucket_lifecycle_configuration(
            Bucket=bucket_name,
            LifecycleConfiguration=lifecycle_config
        )
        print(f"✅ Configured lifecycle rules on bucket: {bucket_name}")
        return True
    except ClientError as e:
        print(f"❌ Error configuring lifecycle rules: {e}")
        return False


def configure_encryption(s3_client, bucket_name):
    """Enable server-side encryption on the S3 bucket."""
    try:
        s3_client.put_bucket_encryption(
            Bucket=bucket_name,
            ServerSideEncryptionConfiguration={
                'Rules': [
                    {
                        'ApplyServerSideEncryptionByDefault': {
                            'SSEAlgorithm': 'AES256'
                        },
                        'BucketKeyEnabled': True
                    }
                ]
            }
        )
        print(f"✅ Enabled server-side encryption on bucket: {bucket_name}")
        return True
    except ClientError as e:
        print(f"❌ Error enabling encryption: {e}")
        return False


def add_bucket_tags(s3_client, bucket_name):
    """Add tags to the S3 bucket."""
    try:
        s3_client.put_bucket_tagging(
            Bucket=bucket_name,
            Tagging={
                'TagSet': [
                    {'Key': 'Project', 'Value': 'ResilienceAtlas'},
                    {'Key': 'Purpose', 'Value': 'CodeDeploy Deployments'},
                    {'Key': 'ManagedBy', 'Value': 'automation'}
                ]
            }
        )
        print(f"✅ Added tags to bucket: {bucket_name}")
        return True
    except ClientError as e:
        print(f"❌ Error adding tags: {e}")
        return False


def main():
    """Main function to set up S3 deployment bucket."""
    print("🚀 Setting up S3 Deployment Bucket for ResilienceAtlas...")
    print("=" * 60)
    
    # Create AWS clients
    clients = create_clients()
    
    # Get account ID and region
    account_id = get_account_id(clients['sts'])
    region = get_region()
    
    print(f"📋 AWS Account ID: {account_id}")
    print(f"📋 AWS Region: {region}")
    
    # Bucket name includes account ID to ensure uniqueness
    bucket_name = f"resilienceatlas-deployments-{account_id}"
    
    print(f"\n📋 Setting up bucket: {bucket_name}")
    
    # Create bucket
    if not create_bucket(clients['s3'], bucket_name, region):
        print("❌ Failed to create S3 bucket. Exiting.")
        sys.exit(1)
    
    # Configure bucket
    print("\n📋 Configuring bucket settings...")
    enable_versioning(clients['s3'], bucket_name)
    block_public_access(clients['s3'], bucket_name)
    configure_encryption(clients['s3'], bucket_name)
    configure_lifecycle_rules(clients['s3'], bucket_name)
    add_bucket_tags(clients['s3'], bucket_name)
    
    # Summary
    print("\n" + "=" * 60)
    print("✅ S3 Deployment Bucket Setup Complete!")
    print("=" * 60)
    print(f"\nBucket Name: {bucket_name}")
    print(f"Region: {region}")
    
    print("\n📋 Bucket Configuration:")
    print("  - Versioning: Enabled (supports rollback)")
    print("  - Public Access: Blocked")
    print("  - Encryption: AES-256 server-side encryption")
    print("  - Lifecycle: Auto-cleanup of old deployments")
    
    print("\n� Add this GitHub Secret to your repository:")
    print(f"  DEPLOYMENT_S3_BUCKET = {bucket_name}")
    
    print("\n📋 Deployment paths:")
    print(f"  - Staging: s3://{bucket_name}/staging/")
    print(f"  - Production: s3://{bucket_name}/production/")


if __name__ == "__main__":
    main()
