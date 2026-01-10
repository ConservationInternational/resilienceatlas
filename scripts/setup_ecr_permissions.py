#!/usr/bin/env python3
"""
Setup ECR Permissions for GitHub Actions and EC2 Instance Roles

This script adds the necessary IAM permissions for:
  1. GitHub Actions OIDC Role - to build and push Docker images to ECR
  2. EC2 Instance Role - to pull Docker images from ECR during deployment

Requirements:
  - AWS CLI configured with 'resilienceatlas' profile
  - boto3 Python package: pip install boto3

Usage:
  python scripts/setup_ecr_permissions.py
  python scripts/setup_ecr_permissions.py --github-role CustomGitHubRole --ec2-role CustomEC2Role
  python scripts/setup_ecr_permissions.py --dry-run
"""

import argparse
import sys
import json
import boto3
from botocore.exceptions import ClientError, NoCredentialsError


# ANSI color codes
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color


def print_color(message, color=''):
    """Print colored message."""
    print(f"{color}{message}{Colors.NC}")


def print_header(message):
    """Print a header message."""
    print_color("=" * 76, Colors.BLUE)
    print_color(message, Colors.BLUE)
    print_color("=" * 76, Colors.BLUE)


def find_role(iam_client, patterns):
    """
    Try to find a role matching common patterns.
    
    Args:
        iam_client: boto3 IAM client
        patterns: List of patterns to search for in role names
        
    Returns:
        str: Role name if found, None otherwise
    """
    try:
        response = iam_client.list_roles()
        roles = response.get('Roles', [])
        
        for pattern in patterns:
            for role in roles:
                if pattern.lower() in role['RoleName'].lower():
                    return role['RoleName']
    except ClientError as e:
        print_color(f"Warning: Could not list roles: {e}", Colors.YELLOW)
    
    return None


def list_matching_roles(iam_client, pattern):
    """
    List roles matching a pattern.
    
    Args:
        iam_client: boto3 IAM client
        pattern: Pattern to search for
    """
    try:
        response = iam_client.list_roles()
        roles = response.get('Roles', [])
        
        matching = [r['RoleName'] for r in roles if pattern.lower() in r['RoleName'].lower()]
        
        if matching:
            print_color(f"\nAvailable roles matching '{pattern}':", Colors.BLUE)
            for role_name in matching[:10]:  # Limit to 10
                print(f"  - {role_name}")
            if len(matching) > 10:
                print(f"  ... and {len(matching) - 10} more")
        else:
            print_color(f"  (no roles found matching '{pattern}')", Colors.YELLOW)
    except ClientError as e:
        print_color(f"Error listing roles: {e}", Colors.RED)


def apply_role_policy(iam_client, role_name, policy_name, policy_document, dry_run=False):
    """
    Apply an inline policy to an IAM role.
    
    Args:
        iam_client: boto3 IAM client
        role_name: Name of the role
        policy_name: Name of the policy
        policy_document: Policy document as dict
        dry_run: If True, only show what would be done
        
    Returns:
        bool: True if successful, False otherwise
    """
    print_color(f"\nConfiguring role: {role_name}", Colors.BLUE)
    
    if dry_run:
        print_color(f"[DRY RUN] Would create/update policy: {policy_name}", Colors.YELLOW)
        print_color("Policy document:", Colors.YELLOW)
        print(json.dumps(policy_document, indent=2))
        return True
    
    try:
        print(f"Creating/updating inline policy: {policy_name}")
        
        iam_client.put_role_policy(
            RoleName=role_name,
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document)
        )
        
        print_color(f"✓ Successfully applied {policy_name} to {role_name}", Colors.GREEN)
        return True
        
    except ClientError as e:
        print_color(f"✗ Failed to apply policy to {role_name}: {e}", Colors.RED)
        return False


def verify_policies(iam_client, role_name):
    """
    Verify and list policies attached to a role.
    
    Args:
        iam_client: boto3 IAM client
        role_name: Name of the role
    """
    try:
        print_color(f"\n{role_name} policies:", Colors.BLUE)
        
        # List inline policies
        response = iam_client.list_role_policies(RoleName=role_name)
        inline_policies = response.get('PolicyNames', [])
        
        if inline_policies:
            print("  Inline policies:")
            for policy in inline_policies:
                print(f"    - {policy}")
        
        # List attached managed policies
        response = iam_client.list_attached_role_policies(RoleName=role_name)
        attached_policies = response.get('AttachedPolicies', [])
        
        if attached_policies:
            print("  Attached managed policies:")
            for policy in attached_policies:
                print(f"    - {policy['PolicyName']}")
        
        if not inline_policies and not attached_policies:
            print("  (no policies attached)")
            
    except ClientError as e:
        print_color(f"Warning: Could not list policies: {e}", Colors.YELLOW)


def main():
    parser = argparse.ArgumentParser(
        description='Setup ECR permissions for ResilienceAtlas deployment',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        '--github-role',
        help='Name of GitHub Actions OIDC role'
    )
    parser.add_argument(
        '--ec2-role',
        help='Name of EC2 instance role'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    parser.add_argument(
        '--profile',
        default='resilienceatlas',
        help='AWS profile to use (default: resilienceatlas)'
    )
    parser.add_argument(
        '--region',
        default='us-east-1',
        help='AWS region (default: us-east-1)'
    )
    
    args = parser.parse_args()
    
    # Print header
    print_header("ECR Permissions Setup for ResilienceAtlas")
    print_color(f"AWS Profile: {args.profile}", Colors.BLUE)
    print_color(f"AWS Region: {args.region}", Colors.BLUE)
    
    if args.dry_run:
        print_color("Mode: DRY RUN (no changes will be made)", Colors.YELLOW)
    else:
        print_color("Mode: LIVE (changes will be applied)", Colors.GREEN)
    
    print_color("=" * 76, Colors.BLUE)
    print()
    
    # Initialize AWS session
    try:
        print_color("Connecting to AWS...", Colors.BLUE)
        session = boto3.Session(profile_name=args.profile)
        iam_client = session.client('iam')
        sts_client = session.client('sts', region_name=args.region)
        
        # Get account ID
        identity = sts_client.get_caller_identity()
        account_id = identity['Account']
        
        print_color(f"✓ Connected as: {identity['Arn']}", Colors.GREEN)
        print_color(f"✓ AWS Account ID: {account_id}", Colors.GREEN)
        print()
        
    except NoCredentialsError:
        print_color(f"✗ No credentials found for profile: {args.profile}", Colors.RED)
        print_color("Make sure AWS CLI is configured with this profile", Colors.RED)
        sys.exit(1)
    except ClientError as e:
        print_color(f"✗ Failed to connect to AWS: {e}", Colors.RED)
        sys.exit(1)
    
    # Detect or prompt for GitHub Actions OIDC role
    github_role = args.github_role
    if not github_role:
        print_color("Detecting GitHub Actions OIDC role...", Colors.BLUE)
        
        github_role = find_role(iam_client, [
            'GitHubActions',
            'github-actions',
            'OIDC',
            'oidc'
        ])
        
        if github_role:
            print_color(f"✓ Found role: {github_role}", Colors.GREEN)
        else:
            print_color("Could not automatically detect GitHub Actions OIDC role", Colors.YELLOW)
            list_matching_roles(iam_client, 'GitHub')
            github_role = input("\nEnter GitHub Actions OIDC role name: ").strip()
    
    # Detect or prompt for EC2 instance role
    ec2_role = args.ec2_role
    if not ec2_role:
        print_color("\nDetecting EC2 instance role...", Colors.BLUE)
        
        ec2_role = find_role(iam_client, [
            'CodeDeploy',
            'EC2',
            'resilienceatlas',
            'instance'
        ])
        
        if ec2_role:
            print_color(f"✓ Found role: {ec2_role}", Colors.GREEN)
        else:
            print_color("Could not automatically detect EC2 instance role", Colors.YELLOW)
            list_matching_roles(iam_client, 'EC2')
            ec2_role = input("\nEnter EC2 instance role name: ").strip()
    
    # Verify role names were provided
    if not github_role or not ec2_role:
        print_color("\n✗ Both role names are required", Colors.RED)
        sys.exit(1)
    
    # Print configuration summary
    print()
    print_header("Configuration Summary")
    print_color(f"  GitHub Actions Role: {github_role}", Colors.GREEN)
    print_color(f"  EC2 Instance Role:   {ec2_role}", Colors.GREEN)
    print_color(f"  AWS Account:         {account_id}", Colors.GREEN)
    print_color("=" * 76, Colors.BLUE)
    print()
    
    # Confirm before applying (unless dry-run)
    if not args.dry_run:
        response = input("Continue with applying permissions? (y/N): ").strip().lower()
        if response != 'y':
            print_color("Aborted by user", Colors.YELLOW)
            sys.exit(0)
        print()
    
    # Define GitHub Actions role policy
    github_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "ECRRepositoryManagement",
                "Effect": "Allow",
                "Action": [
                    "ecr:CreateRepository",
                    "ecr:DescribeRepositories",
                    "ecr:PutLifecyclePolicy",
                    "ecr:SetRepositoryPolicy",
                    "ecr:GetRepositoryPolicy",
                    "ecr:PutImageScanningConfiguration"
                ],
                "Resource": f"arn:aws:ecr:{args.region}:{account_id}:repository/resilienceatlas/*"
            },
            {
                "Sid": "ECRImagePush",
                "Effect": "Allow",
                "Action": [
                    "ecr:GetAuthorizationToken",
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage",
                    "ecr:PutImage",
                    "ecr:InitiateLayerUpload",
                    "ecr:UploadLayerPart",
                    "ecr:CompleteLayerUpload"
                ],
                "Resource": "*"
            }
        ]
    }
    
    # Define EC2 instance role policy
    ec2_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "ECRImagePull",
                "Effect": "Allow",
                "Action": [
                    "ecr:GetAuthorizationToken",
                    "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer",
                    "ecr:BatchGetImage"
                ],
                "Resource": "*"
            },
            {
                "Sid": "ECRDescribeRepositories",
                "Effect": "Allow",
                "Action": [
                    "ecr:DescribeRepositories",
                    "ecr:ListImages"
                ],
                "Resource": f"arn:aws:ecr:{args.region}:{account_id}:repository/resilienceatlas/*"
            }
        ]
    }
    
    # Apply policies
    success_count = 0
    
    if apply_role_policy(iam_client, github_role, 'ECRAccessPolicy', github_policy, args.dry_run):
        success_count += 1
    
    if apply_role_policy(iam_client, ec2_role, 'ECRPullPolicy', ec2_policy, args.dry_run):
        success_count += 1
    
    # Verify policies if not dry-run
    if not args.dry_run and success_count == 2:
        print()
        print_header("Verifying Applied Policies")
        verify_policies(iam_client, github_role)
        verify_policies(iam_client, ec2_role)
    
    # Print summary
    print()
    print_header("Summary")
    
    if args.dry_run:
        print_color("DRY RUN COMPLETE", Colors.YELLOW)
        print()
        print_color("This was a dry run. Run without --dry-run to apply changes:", Colors.YELLOW)
        print_color(f"  python scripts/setup_ecr_permissions.py --github-role {github_role} --ec2-role {ec2_role}", Colors.YELLOW)
    elif success_count == 2:
        print_color("✓ ECR PERMISSIONS SETUP COMPLETE", Colors.GREEN)
        print()
        print_color("Next steps:", Colors.GREEN)
        print(f"  1. Run: python scripts/setup_ecr_repositories.py --region {args.region}")
        print("  2. Commit and push the CI optimization changes")
        print("  3. Deploy to staging to test ECR image builds")
        print("  4. Monitor GitHub Actions logs for image push success")
        print("  5. Monitor EC2 deployment logs for image pull success")
        print()
        print_color("ECR Repository URIs (will be created on first deployment):", Colors.GREEN)
        print(f"  {account_id}.dkr.ecr.{args.region}.amazonaws.com/resilienceatlas/backend")
        print(f"  {account_id}.dkr.ecr.{args.region}.amazonaws.com/resilienceatlas/frontend")
    else:
        print_color(f"✗ SETUP INCOMPLETE: {success_count}/2 policies applied", Colors.RED)
        sys.exit(1)
    
    print_color("=" * 76, Colors.BLUE)
    sys.exit(0)


if __name__ == '__main__':
    main()
