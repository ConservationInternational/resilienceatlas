#!/usr/bin/env python3
"""
AWS CodeDeploy Setup Script for ResilienceAtlas

This script creates and configures AWS CodeDeploy resources for deploying
ResilienceAtlas to EC2 instances.

It creates:
- CodeDeploy Application
- Deployment Groups for staging and production
- Deployment configurations
"""

import boto3
import argparse
import json
import sys
import time
from botocore.exceptions import ClientError


def create_clients(profile=None):
    """Create and return AWS service clients."""
    try:
        session = boto3.Session(profile_name=profile) if profile else boto3.Session()
        return {
            'codedeploy': session.client('codedeploy'),
            'iam': session.client('iam'),
            'ec2': session.client('ec2'),
            'sts': session.client('sts')
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


def create_codedeploy_service_role(iam_client, account_id):
    """Create the IAM service role for CodeDeploy."""
    role_name = "CodeDeployServiceRole"
    
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "",
                "Effect": "Allow",
                "Principal": {
                    "Service": "codedeploy.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    
    try:
        # Create the role
        iam_client.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="Service role for AWS CodeDeploy"
        )
        print(f"✅ Created IAM role: {role_name}")
        
        # Attach the AWS managed policy for CodeDeploy
        iam_client.attach_role_policy(
            RoleName=role_name,
            PolicyArn="arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
        )
        print(f"✅ Attached AWSCodeDeployRole policy to {role_name}")
        
        # Wait for role to be available
        print("⏳ Waiting for IAM role to be available...")
        time.sleep(10)
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"⚠️ IAM role already exists: {role_name}")
        else:
            print(f"❌ Error creating IAM role: {e}")
            return None
    
    return f"arn:aws:iam::{account_id}:role/{role_name}"


def create_codedeploy_application(codedeploy_client, app_name):
    """Create a CodeDeploy application."""
    try:
        codedeploy_client.create_application(
            applicationName=app_name,
            computePlatform='Server',
            tags=[
                {'Key': 'Project', 'Value': 'ResilienceAtlas'},
                {'Key': 'ManagedBy', 'Value': 'CodeDeploy'}
            ]
        )
        print(f"✅ Created CodeDeploy application: {app_name}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'ApplicationAlreadyExistsException':
            print(f"⚠️ CodeDeploy application already exists: {app_name}")
            return True
        else:
            print(f"❌ Error creating CodeDeploy application: {e}")
            return False


def create_deployment_group(codedeploy_client, app_name, group_name, service_role_arn, 
                           ec2_tag_filters, environment):
    """Create a CodeDeploy deployment group."""
    try:
        codedeploy_client.create_deployment_group(
            applicationName=app_name,
            deploymentGroupName=group_name,
            deploymentConfigName='CodeDeployDefault.OneAtATime',
            serviceRoleArn=service_role_arn,
            ec2TagFilters=ec2_tag_filters,
            deploymentStyle={
                'deploymentType': 'IN_PLACE',
                'deploymentOption': 'WITHOUT_TRAFFIC_CONTROL'
            },
            autoRollbackConfiguration={
                'enabled': True,
                'events': [
                    'DEPLOYMENT_FAILURE',
                    'DEPLOYMENT_STOP_ON_ALARM'
                ]
            },
            tags=[
                {'Key': 'Project', 'Value': 'ResilienceAtlas'},
                {'Key': 'Environment', 'Value': environment}
            ]
        )
        print(f"✅ Created deployment group: {group_name}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'DeploymentGroupAlreadyExistsException':
            print(f"⚠️ Deployment group already exists: {group_name}")
            return True
        else:
            print(f"❌ Error creating deployment group: {e}")
            return False


def create_deployment_config(codedeploy_client, config_name, minimum_healthy_hosts):
    """Create a custom deployment configuration."""
    try:
        codedeploy_client.create_deployment_config(
            deploymentConfigName=config_name,
            minimumHealthyHosts={
                'type': 'HOST_COUNT',
                'value': minimum_healthy_hosts
            },
            computePlatform='Server'
        )
        print(f"✅ Created deployment configuration: {config_name}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'DeploymentConfigAlreadyExistsException':
            print(f"⚠️ Deployment configuration already exists: {config_name}")
            return True
        else:
            print(f"❌ Error creating deployment configuration: {e}")
            return False


def save_configuration(config):
    """Save CodeDeploy configuration to JSON file."""
    with open('codedeploy_configuration.json', 'w') as f:
        json.dump(config, f, indent=2)
    print("✅ Configuration saved to codedeploy_configuration.json")


def main(profile=None):
    """Main function to set up CodeDeploy resources."""
    print("🚀 Setting up AWS CodeDeploy for ResilienceAtlas...")
    print("=" * 60)
    
    # Create AWS clients
    clients = create_clients(profile)
    
    # Get account ID
    account_id = get_account_id(clients['sts'])
    print(f"📋 AWS Account ID: {account_id}")
    
    # Configuration
    app_name = "resilienceatlas"
    
    # Create service role
    print("\n📋 Creating CodeDeploy service role...")
    service_role_arn = create_codedeploy_service_role(clients['iam'], account_id)
    if not service_role_arn:
        print("❌ Failed to create service role. Exiting.")
        sys.exit(1)
    
    # Create CodeDeploy application
    print("\n📋 Creating CodeDeploy application...")
    if not create_codedeploy_application(clients['codedeploy'], app_name):
        print("❌ Failed to create CodeDeploy application. Exiting.")
        sys.exit(1)
    
    # Create custom deployment configurations
    print("\n📋 Creating deployment configurations...")
    create_deployment_config(clients['codedeploy'], 'ResilienceAtlas-SingleInstance', 0)
    
    # SINGLE-INSTANCE SUPPORT:
    # Both deployment groups target the same EC2 instance via Project tag.
    # The instance can run both staging and production simultaneously.
    # CodeDeploy determines which environment to deploy based on deployment group name.
    
    # Create staging deployment group
    print("\n📋 Creating staging deployment group...")
    staging_tag_filters = [
        {
            'Key': 'Project',
            'Value': 'ResilienceAtlas',
            'Type': 'KEY_AND_VALUE'
        }
    ]
    
    create_deployment_group(
        clients['codedeploy'],
        app_name,
        'resilienceatlas-staging',
        service_role_arn,
        staging_tag_filters,
        'staging'
    )
    
    # Create production deployment group
    print("\n📋 Creating production deployment group...")
    production_tag_filters = [
        {
            'Key': 'Project',
            'Value': 'ResilienceAtlas',
            'Type': 'KEY_AND_VALUE'
        }
    ]
    
    create_deployment_group(
        clients['codedeploy'],
        app_name,
        'resilienceatlas-production',
        service_role_arn,
        production_tag_filters,
        'production'
    )
    
    # Save configuration
    config = {
        'application': {
            'name': app_name
        },
        'service_role': {
            'arn': service_role_arn
        },
        'deployment_groups': {
            'staging': {
                'name': 'resilienceatlas-staging',
                'tag_filters': staging_tag_filters
            },
            'production': {
                'name': 'resilienceatlas-production',
                'tag_filters': production_tag_filters
            }
        },
        'deployment_configs': {
            'single_instance': 'ResilienceAtlas-SingleInstance'
        },
        'single_instance_mode': True
    }
    
    print("\n📋 Saving configuration...")
    save_configuration(config)
    
    # Summary
    print("\n" + "=" * 60)
    print("✅ CodeDeploy Setup Complete!")
    print("=" * 60)
    print(f"\nApplication Name: {app_name}")
    print(f"Service Role ARN: {service_role_arn}")
    print("\nDeployment Groups:")
    print("  - resilienceatlas-staging (for staging environment)")
    print("  - resilienceatlas-production (for production environment)")
    
    print("\n📋 Single-Instance Mode:")
    print("  Both staging and production can run on the SAME EC2 instance!")
    print("  - Staging:    ports 3000 (frontend), 3001 (backend), 5432 (db)")
    print("  - Production: ports 4000 (frontend), 4001 (backend)")
    print("  - Separate directories: /opt/resilienceatlas-staging, /opt/resilienceatlas-production")
    
    print("\n📋 Next Steps:")
    print("1. Tag your EC2 instance with: Project=ResilienceAtlas")
    print("2. Install CodeDeploy agent on EC2 instance:")
    print("   Run: sudo bash scripts/install-codedeploy-agent.sh")
    print("3. Configure GitHub Actions secrets for CodeDeploy")
    print("4. Push to 'staging' branch for staging, 'main' for production")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Set up AWS CodeDeploy for ResilienceAtlas')
    parser.add_argument('--profile', '-p', help='AWS profile name from ~/.aws/credentials')
    args = parser.parse_args()
    main(profile=args.profile)
