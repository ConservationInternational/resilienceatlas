#!/usr/bin/env python3
"""
AWS IAM Setup Script for ResilienceAtlas EC2 Deployment

This script creates the necessary IAM users, groups, and policies
for deploying ResilienceAtlas to EC2 instances.
"""

import boto3
import json
import sys
from botocore.exceptions import ClientError

def create_iam_client():
    """Create and return an IAM client."""
    try:
        return boto3.client('iam')
    except Exception as e:
        print(f"❌ Error creating IAM client: {e}")
        sys.exit(1)

def create_deployment_policy():
    """Create the deployment policy document."""
    return {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "EC2Management",
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeInstances",
                    "ec2:DescribeSecurityGroups",
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupIngress",
                    "ec2:DescribeImages",
                    "ec2:DescribeKeyPairs",
                    "ec2:CreateTags",
                    "ec2:DescribeTags"
                ],
                "Resource": "*"
            },
            {
                "Sid": "ELBManagement",
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:DescribeLoadBalancers",
                    "elasticloadbalancing:DescribeTargetGroups",
                    "elasticloadbalancing:DescribeTargetHealth",
                    "elasticloadbalancing:RegisterTargets",
                    "elasticloadbalancing:DeregisterTargets",
                    "elasticloadbalancing:ModifyTargetGroup",
                    "elasticloadbalancing:CreateTargetGroup",
                    "elasticloadbalancing:DeleteTargetGroup",
                    "elasticloadbalancing:ModifyLoadBalancerAttributes",
                    "elasticloadbalancing:CreateListener",
                    "elasticloadbalancing:ModifyListener",
                    "elasticloadbalancing:DeleteListener",
                    "elasticloadbalancing:CreateRule",
                    "elasticloadbalancing:ModifyRule",
                    "elasticloadbalancing:DeleteRule"
                ],
                "Resource": "*"
            },
            {
                "Sid": "Route53Management",
                "Effect": "Allow",
                "Action": [
                    "route53:ListHostedZones",
                    "route53:GetHostedZone",
                    "route53:ListResourceRecordSets",
                    "route53:ChangeResourceRecordSets",
                    "route53:GetChange"
                ],
                "Resource": "*"
            },
            {
                "Sid": "SecretsManagerAccess",
                "Effect": "Allow",
                "Action": [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ],
                "Resource": "arn:aws:secretsmanager:*:*:secret:resilienceatlas/*"
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
                    "codedeploy:BatchGetDeploymentGroups"
                ],
                "Resource": [
                    "arn:aws:codedeploy:*:*:application:resilienceatlas",
                    "arn:aws:codedeploy:*:*:deploymentgroup:resilienceatlas/*",
                    "arn:aws:codedeploy:*:*:deploymentconfig:*"
                ]
            },
            {
                "Sid": "S3DeploymentBucket",
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:GetObjectVersion",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::resilienceatlas-deployments-*",
                    "arn:aws:s3:::resilienceatlas-deployments-*/*"
                ]
            }
        ]
    }

def create_policy(iam_client, policy_name, policy_document):
    """Create an IAM policy."""
    try:
        response = iam_client.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document),
            Description="Policy for ResilienceAtlas EC2 deployment operations"
        )
        print(f"✅ Created policy: {policy_name}")
        return response['Policy']['Arn']
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            # Policy already exists, get its ARN
            account_id = boto3.client('sts').get_caller_identity()['Account']
            policy_arn = f"arn:aws:iam::{account_id}:policy/{policy_name}"
            print(f"⚠️ Policy already exists: {policy_name}")
            return policy_arn
        else:
            print(f"❌ Error creating policy {policy_name}: {e}")
            return None

def create_group(iam_client, group_name):
    """Create an IAM group."""
    try:
        iam_client.create_group(GroupName=group_name)
        print(f"✅ Created group: {group_name}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"⚠️ Group already exists: {group_name}")
        else:
            print(f"❌ Error creating group {group_name}: {e}")
            return False
    return True

def attach_policy_to_group(iam_client, group_name, policy_arn):
    """Attach a policy to a group."""
    try:
        iam_client.attach_group_policy(
            GroupName=group_name,
            PolicyArn=policy_arn
        )
        print(f"✅ Attached policy to group: {group_name}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchEntity':
            print(f"❌ Group or policy not found: {e}")
        else:
            print(f"❌ Error attaching policy to group: {e}")
        return False

def create_user(iam_client, username):
    """Create an IAM user."""
    try:
        iam_client.create_user(UserName=username)
        print(f"✅ Created user: {username}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"⚠️ User already exists: {username}")
            return True
        else:
            print(f"❌ Error creating user {username}: {e}")
            return False

def add_user_to_group(iam_client, username, group_name):
    """Add a user to a group."""
    try:
        iam_client.add_user_to_group(
            GroupName=group_name,
            UserName=username
        )
        print(f"✅ Added user {username} to group {group_name}")
        return True
    except ClientError as e:
        print(f"❌ Error adding user to group: {e}")
        return False

def create_access_key(iam_client, username):
    """Create access keys for a user."""
    try:
        response = iam_client.create_access_key(UserName=username)
        access_key = response['AccessKey']
        print(f"✅ Created access key for user: {username}")
        print(f"🔑 Access Key ID: {access_key['AccessKeyId']}")
        print(f"🔐 Secret Access Key: {access_key['SecretAccessKey']}")
        print("⚠️ IMPORTANT: Save these credentials securely! They won't be shown again.")
        return {
            'AccessKeyId': access_key['AccessKeyId'],
            'SecretAccessKey': access_key['SecretAccessKey']
        }
    except ClientError as e:
        print(f"❌ Error creating access key: {e}")
        return None

def main():
    """Main function to set up IAM resources."""
    print("🚀 Setting up IAM resources for ResilienceAtlas EC2 deployment...")
    
    iam_client = create_iam_client()
    
    # Configuration
    policy_name = "ResilienceAtlasDeploymentPolicy"
    group_name = "ResilienceAtlasDeploymentGroup"
    ci_user = "resilienceatlas-ci"
    admin_user = "resilienceatlas-admin"
    
    # Create policy
    print("\n📋 Creating deployment policy...")
    policy_document = create_deployment_policy()
    policy_arn = create_policy(iam_client, policy_name, policy_document)
    
    if not policy_arn:
        print("❌ Failed to create policy. Exiting.")
        sys.exit(1)
    
    # Create group
    print("\n👥 Creating deployment group...")
    if not create_group(iam_client, group_name):
        print("❌ Failed to create group. Exiting.")
        sys.exit(1)
    
    # Attach policy to group
    print("\n🔗 Attaching policy to group...")
    if not attach_policy_to_group(iam_client, group_name, policy_arn):
        print("❌ Failed to attach policy to group. Exiting.")
        sys.exit(1)
    
    # Create users
    print("\n👤 Creating users...")
    users = [ci_user, admin_user]
    created_users = []
    
    for username in users:
        if create_user(iam_client, username):
            if add_user_to_group(iam_client, username, group_name):
                created_users.append(username)
    
    # Create access keys
    print("\n🔑 Creating access keys...")
    credentials = {}
    
    for username in created_users:
        print(f"\nCreating access key for {username}:")
        creds = create_access_key(iam_client, username)
        if creds:
            credentials[username] = creds
    
    # Summary
    print("\n" + "="*60)
    print("✅ IAM Setup Complete!")
    print("="*60)
    print(f"Policy ARN: {policy_arn}")
    print(f"Group: {group_name}")
    print(f"Users created: {', '.join(created_users)}")
    
    print("\n📋 Next Steps:")
    print("1. Run scripts/setup_github_oidc.py to set up OIDC authentication (RECOMMENDED)")
    print("   - This eliminates the need for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
    print("   - More secure than long-lived access keys")
    print("2. Set up EC2 instances for staging and production")
    print("3. Configure security groups with appropriate rules")
    print("4. Set up Application Load Balancer for routing")
    print("5. Configure Route53 for domain management")
    
    print("\n🔐 GitHub Secrets Required (after running setup_github_oidc.py):")
    print("   - AWS_OIDC_ROLE_ARN (from setup_github_oidc.py)")
    print("   - DEPLOYMENT_S3_BUCKET (from setup_s3_bucket.py)")
    
    print("\n⚠️ Security Recommendations:")
    print("- Use OIDC instead of access keys for GitHub Actions")
    print("- Store credentials securely")
    print("- Use principle of least privilege")
    print("- Regularly rotate access keys (if still using them)")
    print("- Enable MFA for IAM users")
    print("- Monitor CloudTrail logs for API usage")

if __name__ == "__main__":
    main()
