#!/usr/bin/env python3
"""
Add TiTiler/SAM deployment permissions to existing GitHub OIDC role.

This script adds the necessary IAM permissions for deploying TiTiler
via AWS SAM to an existing IAM role used by GitHub Actions.

Usage:
    python add_titiler_permissions.py --role-name ResilienceAtlas-GitHubActions
    python add_titiler_permissions.py --role-name ResilienceAtlas-GitHubActions --profile myprofile
"""

import boto3
import argparse
import json
import sys
from botocore.exceptions import ClientError

POLICY_NAME = "TiTilerSAMDeploymentPolicy"

TITILER_POLICY = {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudFormationFullAccess",
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:UpdateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:DescribeStackEvents",
                "cloudformation:DescribeStackResources",
                "cloudformation:GetTemplate",
                "cloudformation:ValidateTemplate",
                "cloudformation:CreateChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:ListStackResources"
            ],
            "Resource": "*"
        },
        {
            "Sid": "LambdaFullAccess",
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration",
                "lambda:DeleteFunction",
                "lambda:GetFunction",
                "lambda:GetFunctionConfiguration",
                "lambda:ListFunctions",
                "lambda:AddPermission",
                "lambda:RemovePermission",
                "lambda:InvokeFunction",
                "lambda:PublishVersion",
                "lambda:CreateAlias",
                "lambda:UpdateAlias",
                "lambda:DeleteAlias",
                "lambda:TagResource",
                "lambda:UntagResource",
                "lambda:ListTags"
            ],
            "Resource": "*"
        },
        {
            "Sid": "APIGatewayFullAccess",
            "Effect": "Allow",
            "Action": [
                "apigateway:GET",
                "apigateway:POST",
                "apigateway:PUT",
                "apigateway:DELETE",
                "apigateway:PATCH",
                "apigateway:TagResource",
                "apigateway:UntagResource"
            ],
            "Resource": "*"
        },
        {
            "Sid": "S3ArtifactsBucket",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::*sam*",
                "arn:aws:s3:::*sam*/*",
                "arn:aws:s3:::*artifacts*",
                "arn:aws:s3:::*artifacts*/*"
            ]
        },
        {
            "Sid": "ECRAccess",
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:DescribeRepositories",
                "ecr:CreateRepository",
                "ecr:DeleteRepository",
                "ecr:SetRepositoryPolicy",
                "ecr:TagResource"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Route53Access",
            "Effect": "Allow",
            "Action": [
                "route53:GetHostedZone",
                "route53:ChangeResourceRecordSets",
                "route53:ListResourceRecordSets",
                "route53:GetChange"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/*",
                "arn:aws:route53:::change/*"
            ]
        },
        {
            "Sid": "ACMCertificateAccess",
            "Effect": "Allow",
            "Action": [
                "acm:RequestCertificate",
                "acm:DescribeCertificate",
                "acm:DeleteCertificate",
                "acm:ListCertificates",
                "acm:AddTagsToCertificate"
            ],
            "Resource": "*"
        },
        {
            "Sid": "IAMPassRole",
            "Effect": "Allow",
            "Action": [
                "iam:PassRole",
                "iam:GetRole",
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:TagRole"
            ],
            "Resource": [
                "arn:aws:iam::*:role/*titiler*",
                "arn:aws:iam::*:role/*TiTiler*",
                "arn:aws:iam::*:role/*lambda*",
                "arn:aws:iam::*:role/*Lambda*"
            ]
        },
        {
            "Sid": "CloudWatchLogsAccess",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:DeleteLogGroup",
                "logs:PutRetentionPolicy",
                "logs:TagResource"
            ],
            "Resource": "*"
        }
    ]
}


def create_client(profile=None):
    """Create and return IAM client."""
    try:
        session = boto3.Session(profile_name=profile) if profile else boto3.Session()
        return session.client('iam')
    except Exception as e:
        print(f"❌ Error creating AWS client: {e}")
        sys.exit(1)


def check_role_exists(iam_client, role_name):
    """Check if the IAM role exists."""
    try:
        iam_client.get_role(RoleName=role_name)
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchEntity':
            return False
        raise


def add_inline_policy(iam_client, role_name, policy_name, policy_document):
    """Add an inline policy to the role."""
    try:
        iam_client.put_role_policy(
            RoleName=role_name,
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document)
        )
        print(f"✅ Added policy '{policy_name}' to role '{role_name}'")
        return True
    except ClientError as e:
        print(f"❌ Error adding policy: {e}")
        return False


def list_role_policies(iam_client, role_name):
    """List existing inline policies on the role."""
    try:
        response = iam_client.list_role_policies(RoleName=role_name)
        return response.get('PolicyNames', [])
    except ClientError as e:
        print(f"❌ Error listing policies: {e}")
        return []


def get_policy_document(iam_client, role_name, policy_name):
    """Get the policy document for an inline policy."""
    try:
        response = iam_client.get_role_policy(
            RoleName=role_name,
            PolicyName=policy_name
        )
        return response.get('PolicyDocument')
    except ClientError as e:
        return None


def main():
    parser = argparse.ArgumentParser(
        description='Add TiTiler/SAM deployment permissions to existing IAM role'
    )
    parser.add_argument(
        '--role-name',
        required=True,
        help='Name of the existing IAM role to modify'
    )
    parser.add_argument(
        '--profile',
        help='AWS profile to use (optional)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Print policy without applying'
    )
    
    args = parser.parse_args()
    
    print(f"\n{'='*60}")
    print("TiTiler Permissions Setup")
    print(f"{'='*60}\n")
    
    if args.dry_run:
        print("🔍 DRY RUN - Policy that would be added:\n")
        print(json.dumps(TITILER_POLICY, indent=2))
        return
    
    # Create IAM client
    iam_client = create_client(args.profile)
    
    # Check if role exists
    if not check_role_exists(iam_client, args.role_name):
        print(f"❌ Role '{args.role_name}' does not exist")
        sys.exit(1)
    
    print(f"✅ Found role: {args.role_name}")
    
    # List existing policies
    existing_policies = list_role_policies(iam_client, args.role_name)
    print(f"📋 Existing inline policies: {existing_policies or 'None'}")
    
    # Check if policy already exists
    if POLICY_NAME in existing_policies:
        print(f"⚠️  Policy '{POLICY_NAME}' already exists. Updating...")
    
    # Add/update the policy
    if add_inline_policy(iam_client, args.role_name, POLICY_NAME, TITILER_POLICY):
        print(f"\n{'='*60}")
        print("✅ TiTiler permissions added successfully!")
        print(f"{'='*60}")
        print("\nThe role now has permissions for:")
        print("  • CloudFormation (stack management)")
        print("  • Lambda (function deployment)")
        print("  • API Gateway (REST API creation)")
        print("  • S3 (SAM artifact storage)")
        print("  • ECR (container image storage)")
        print("  • Route53 (DNS record management)")
        print("  • ACM (SSL certificate creation)")
        print("  • IAM (Lambda execution role management)")
        print("  • CloudWatch Logs (log group creation)")
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
