#!/usr/bin/env python3
"""
GitHub OIDC Provider Setup Script for ResilienceAtlas

This script creates the IAM OIDC identity provider and role that allows
GitHub Actions to authenticate with AWS without using long-lived credentials.

Benefits of OIDC over Access Keys:
- No secrets to rotate or manage
- Credentials are short-lived and automatically expire
- Better security posture (no stored credentials to leak)
- Fine-grained access control based on repo/branch/environment
"""

import boto3
import argparse
import json
import sys
from botocore.exceptions import ClientError

# GitHub's OIDC provider URL and thumbprint
GITHUB_OIDC_URL = "https://token.actions.githubusercontent.com"
# This is GitHub's OIDC thumbprint - it rarely changes
# See: https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
GITHUB_OIDC_THUMBPRINT = "6938fd4d98bab03faadb97b34396831e3780aea1"


def create_clients(profile=None):
    """Create and return AWS service clients."""
    try:
        session = boto3.Session(profile_name=profile) if profile else boto3.Session()
        return {
            'iam': session.client('iam'),
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


def create_oidc_provider(iam_client):
    """Create the GitHub OIDC identity provider."""
    try:
        response = iam_client.create_open_id_connect_provider(
            Url=GITHUB_OIDC_URL,
            ClientIDList=['sts.amazonaws.com'],
            ThumbprintList=[GITHUB_OIDC_THUMBPRINT],
            Tags=[
                {'Key': 'Project', 'Value': 'ResilienceAtlas'},
                {'Key': 'Purpose', 'Value': 'GitHub Actions OIDC'},
                {'Key': 'ManagedBy', 'Value': 'automation'}
            ]
        )
        print(f"✅ Created OIDC provider: {response['OpenIDConnectProviderArn']}")
        return response['OpenIDConnectProviderArn']
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            # Provider already exists, get its ARN
            account_id = boto3.client('sts').get_caller_identity()['Account']
            arn = f"arn:aws:iam::{account_id}:oidc-provider/token.actions.githubusercontent.com"
            print(f"⚠️ OIDC provider already exists: {arn}")
            return arn
        else:
            print(f"❌ Error creating OIDC provider: {e}")
            return None


def create_trust_policy(account_id, github_org, github_repo):
    """Create the trust policy for the GitHub Actions role."""
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Federated": f"arn:aws:iam::{account_id}:oidc-provider/token.actions.githubusercontent.com"
                },
                "Action": "sts:AssumeRoleWithWebIdentity",
                "Condition": {
                    "StringEquals": {
                        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                    },
                    "StringLike": {
                        # Allow from specific repo, any branch/environment
                        "token.actions.githubusercontent.com:sub": f"repo:{github_org}/{github_repo}:*"
                    }
                }
            }
        ]
    }


def create_deployment_policy():
    """Create the permissions policy for GitHub Actions deployments."""
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "S3DeploymentBucket",
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:GetObjectVersion",
                    "s3:DeleteObject",
                    "s3:ListBucket",
                    "s3:GetBucketLocation"
                ],
                "Resource": [
                    "arn:aws:s3:::resilienceatlas-deployments-*",
                    "arn:aws:s3:::resilienceatlas-deployments-*/*"
                ]
            },
            {
                "Sid": "S3BucketCheck",
                "Effect": "Allow",
                "Action": [
                    "s3:HeadBucket"
                ],
                "Resource": "*"
            },
            {
                "Sid": "CodeDeployManagement",
                "Effect": "Allow",
                "Action": [
                    "codedeploy:CreateDeployment",
                    "codedeploy:GetDeployment",
                    "codedeploy:GetDeploymentConfig",
                    "codedeploy:GetApplicationRevision",
                    "codedeploy:RegisterApplicationRevision",
                    "codedeploy:GetApplication",
                    "codedeploy:ListDeploymentGroups",
                    "codedeploy:ListDeployments",
                    "codedeploy:GetDeploymentGroup",
                    "codedeploy:BatchGetDeployments",
                    "codedeploy:BatchGetDeploymentGroups",
                    "codedeploy:ListDeploymentTargets",
                    "codedeploy:GetDeploymentTarget"
                ],
                "Resource": [
                    "arn:aws:codedeploy:*:*:application:resilienceatlas",
                    "arn:aws:codedeploy:*:*:deploymentgroup:resilienceatlas/*",
                    "arn:aws:codedeploy:*:*:deploymentconfig:*"
                ]
            },
            {
                "Sid": "CodeDeployWait",
                "Effect": "Allow",
                "Action": [
                    "codedeploy:GetDeployment"
                ],
                "Resource": "*"
            }
        ]
    }


def create_iam_role(iam_client, role_name, trust_policy, permissions_policy):
    """Create the IAM role for GitHub Actions."""
    try:
        # Create the role
        response = iam_client.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="Role for GitHub Actions to deploy ResilienceAtlas via OIDC",
            MaxSessionDuration=3600,  # 1 hour
            Tags=[
                {'Key': 'Project', 'Value': 'ResilienceAtlas'},
                {'Key': 'Purpose', 'Value': 'GitHub Actions OIDC'},
                {'Key': 'ManagedBy', 'Value': 'automation'}
            ]
        )
        role_arn = response['Role']['Arn']
        print(f"✅ Created IAM role: {role_name}")

        # Attach inline policy
        iam_client.put_role_policy(
            RoleName=role_name,
            PolicyName='GitHubActionsDeploymentPolicy',
            PolicyDocument=json.dumps(permissions_policy)
        )
        print(f"✅ Attached deployment policy to role")

        return role_arn

    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            account_id = boto3.client('sts').get_caller_identity()['Account']
            role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
            print(f"⚠️ Role already exists: {role_name}")
            
            # Update the trust policy
            try:
                iam_client.update_assume_role_policy(
                    RoleName=role_name,
                    PolicyDocument=json.dumps(trust_policy)
                )
                print(f"✅ Updated trust policy for role")
            except ClientError as update_error:
                print(f"⚠️ Could not update trust policy: {update_error}")

            # Update the permissions policy
            try:
                iam_client.put_role_policy(
                    RoleName=role_name,
                    PolicyName='GitHubActionsDeploymentPolicy',
                    PolicyDocument=json.dumps(permissions_policy)
                )
                print(f"✅ Updated deployment policy for role")
            except ClientError as update_error:
                print(f"⚠️ Could not update permissions policy: {update_error}")

            return role_arn
        else:
            print(f"❌ Error creating role: {e}")
            return None


def main(profile=None):
    """Main function to set up GitHub OIDC."""
    print("🚀 Setting up GitHub OIDC for ResilienceAtlas...")
    print("=" * 60)

    # Configuration
    github_org = "ConservationInternational"
    github_repo = "resilienceatlas"
    role_name = "GitHubActionsResilienceAtlasRole"

    # Create AWS clients
    clients = create_clients(profile)

    # Get account ID
    account_id = get_account_id(clients['sts'])
    print(f"📋 AWS Account ID: {account_id}")
    print(f"📋 GitHub Repo: {github_org}/{github_repo}")

    # Create OIDC provider
    print("\n📋 Creating OIDC Identity Provider...")
    oidc_arn = create_oidc_provider(clients['iam'])
    if not oidc_arn:
        print("❌ Failed to create OIDC provider. Exiting.")
        sys.exit(1)

    # Create trust policy
    print("\n📋 Creating IAM Role with Trust Policy...")
    trust_policy = create_trust_policy(account_id, github_org, github_repo)
    permissions_policy = create_deployment_policy()

    role_arn = create_iam_role(
        clients['iam'],
        role_name,
        trust_policy,
        permissions_policy
    )

    if not role_arn:
        print("❌ Failed to create IAM role. Exiting.")
        sys.exit(1)

    # Summary
    print("\n" + "=" * 60)
    print("✅ GitHub OIDC Setup Complete!")
    print("=" * 60)

    print("\n📋 Resources Created:")
    print(f"  OIDC Provider: {oidc_arn}")
    print(f"  IAM Role: {role_arn}")

    print("\n🔐 Add these GitHub Secrets to your repository:")
    print(f"  AWS_OIDC_ROLE_ARN = {role_arn}")

    print("\n📋 Trust Policy allows:")
    print(f"  - Repository: {github_org}/{github_repo}")
    print(f"  - All branches and environments")

    print("\n📋 Permissions granted:")
    print("  - S3: Upload/download deployment packages")
    print("  - CodeDeploy: Create and monitor deployments")

    print("\n🔒 Security Benefits of OIDC:")
    print("  - No long-lived credentials to manage or rotate")
    print("  - Credentials expire automatically after 1 hour")
    print("  - Can't be leaked since they're never stored")
    print("  - Audit trail in CloudTrail tied to GitHub workflow runs")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Set up GitHub OIDC provider for AWS')
    parser.add_argument('--profile', '-p', help='AWS profile name from ~/.aws/credentials')
    args = parser.parse_args()
    main(profile=args.profile)
