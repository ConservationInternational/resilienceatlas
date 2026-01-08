#!/usr/bin/env python3
"""
EC2 Instance Role Setup Script for ResilienceAtlas

This script creates the IAM instance profile that EC2 instances need
to communicate with CodeDeploy and access required AWS services.
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


def create_instance_role(iam_client, role_name):
    """Create the IAM role for EC2 instances."""
    
    trust_policy = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }
    
    try:
        iam_client.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=json.dumps(trust_policy),
            Description="IAM role for ResilienceAtlas EC2 instances with CodeDeploy access"
        )
        print(f"✅ Created IAM role: {role_name}")
        return True
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"⚠️ IAM role already exists: {role_name}")
            return True
        else:
            print(f"❌ Error creating IAM role: {e}")
            return False


def create_instance_policy(iam_client, policy_name, account_id):
    """Create the IAM policy for EC2 instances."""
    
    policy_document = {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "CodeDeployAgent",
                "Effect": "Allow",
                "Action": [
                    "s3:Get*",
                    "s3:List*"
                ],
                "Resource": [
                    "arn:aws:s3:::aws-codedeploy-*/*",
                    "arn:aws:s3:::aws-codedeploy-*"
                ]
            },
            {
                "Sid": "CodeDeployAppBucket",
                "Effect": "Allow",
                "Action": [
                    "s3:Get*",
                    "s3:List*"
                ],
                "Resource": [
                    f"arn:aws:s3:::resilienceatlas-deployments-{account_id}/*",
                    f"arn:aws:s3:::resilienceatlas-deployments-{account_id}"
                ]
            },
            {
                "Sid": "ECRAccess",
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
                "Sid": "SecretsManagerAccess",
                "Effect": "Allow",
                "Action": [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ],
                "Resource": f"arn:aws:secretsmanager:*:{account_id}:secret:resilienceatlas/*"
            },
            {
                "Sid": "SSMAccess",
                "Effect": "Allow",
                "Action": [
                    "ssm:GetParameter",
                    "ssm:GetParameters",
                    "ssm:GetParametersByPath"
                ],
                "Resource": f"arn:aws:ssm:*:{account_id}:parameter/resilienceatlas/*"
            },
            {
                "Sid": "CloudWatchLogs",
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                    "logs:DescribeLogStreams"
                ],
                "Resource": [
                    f"arn:aws:logs:*:{account_id}:log-group:/aws/ec2/resilienceatlas/*",
                    f"arn:aws:logs:*:{account_id}:log-group:/aws/ec2/resilienceatlas/*:*"
                ]
            },
            {
                "Sid": "CloudWatchMetrics",
                "Effect": "Allow",
                "Action": [
                    "cloudwatch:PutMetricData"
                ],
                "Resource": "*",
                "Condition": {
                    "StringEquals": {
                        "cloudwatch:namespace": "ResilienceAtlas"
                    }
                }
            },
            {
                "Sid": "DescribeInstances",
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeTags",
                    "ec2:DescribeInstances"
                ],
                "Resource": "*"
            }
        ]
    }
    
    try:
        response = iam_client.create_policy(
            PolicyName=policy_name,
            PolicyDocument=json.dumps(policy_document),
            Description="Policy for ResilienceAtlas EC2 instances"
        )
        print(f"✅ Created IAM policy: {policy_name}")
        return response['Policy']['Arn']
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"⚠️ IAM policy already exists: {policy_name}")
            return f"arn:aws:iam::{account_id}:policy/{policy_name}"
        else:
            print(f"❌ Error creating IAM policy: {e}")
            return None


def attach_policies(iam_client, role_name, policy_arns):
    """Attach policies to the IAM role."""
    for policy_arn in policy_arns:
        try:
            iam_client.attach_role_policy(
                RoleName=role_name,
                PolicyArn=policy_arn
            )
            print(f"✅ Attached policy: {policy_arn.split('/')[-1]}")
        except ClientError as e:
            if e.response['Error']['Code'] != 'EntityAlreadyExists':
                print(f"❌ Error attaching policy {policy_arn}: {e}")


def create_instance_profile(iam_client, profile_name, role_name):
    """Create an instance profile and add the role to it."""
    try:
        iam_client.create_instance_profile(InstanceProfileName=profile_name)
        print(f"✅ Created instance profile: {profile_name}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"⚠️ Instance profile already exists: {profile_name}")
        else:
            print(f"❌ Error creating instance profile: {e}")
            return False
    
    try:
        iam_client.add_role_to_instance_profile(
            InstanceProfileName=profile_name,
            RoleName=role_name
        )
        print(f"✅ Added role {role_name} to instance profile")
    except ClientError as e:
        if e.response['Error']['Code'] == 'LimitExceeded':
            print(f"⚠️ Role already attached to instance profile")
        else:
            print(f"❌ Error adding role to instance profile: {e}")
    
    return True


def main(profile=None):
    """Main function to set up EC2 instance role."""
    print("🚀 Setting up EC2 Instance Role for ResilienceAtlas...")
    print("=" * 60)
    
    # Create AWS clients
    clients = create_clients(profile)
    
    # Get account ID
    account_id = get_account_id(clients['sts'])
    print(f"📋 AWS Account ID: {account_id}")
    
    # Configuration
    role_name = "ResilienceAtlasEC2Role"
    policy_name = "ResilienceAtlasEC2Policy"
    profile_name = "ResilienceAtlasEC2Profile"
    
    # Create the IAM role
    print("\n📋 Creating IAM role...")
    if not create_instance_role(clients['iam'], role_name):
        print("❌ Failed to create IAM role. Exiting.")
        sys.exit(1)
    
    # Create the custom policy
    print("\n📋 Creating IAM policy...")
    custom_policy_arn = create_instance_policy(clients['iam'], policy_name, account_id)
    
    # Attach policies
    print("\n📋 Attaching policies...")
    policies_to_attach = [
        # AWS managed policies
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    ]
    
    if custom_policy_arn:
        policies_to_attach.append(custom_policy_arn)
    
    attach_policies(clients['iam'], role_name, policies_to_attach)
    
    # Create instance profile
    print("\n📋 Creating instance profile...")
    create_instance_profile(clients['iam'], profile_name, role_name)
    
    # Wait for resources to be available
    print("\n⏳ Waiting for IAM resources to propagate...")
    time.sleep(10)
    
    # Summary
    print("\n" + "=" * 60)
    print("✅ EC2 Instance Role Setup Complete!")
    print("=" * 60)
    print(f"\nRole Name: {role_name}")
    print(f"Policy Name: {policy_name}")
    print(f"Instance Profile: {profile_name}")
    
    print("\n📋 Next Steps:")
    print("1. Attach the instance profile to your EC2 instances:")
    print(f"   aws ec2 associate-iam-instance-profile \\")
    print(f"     --instance-id <your-instance-id> \\")
    print(f"     --iam-instance-profile Name={profile_name}")
    print("")
    print("2. Or specify the instance profile when launching new instances:")
    print(f"   --iam-instance-profile Name={profile_name}")
    print("")
    print("3. After attaching, install the CodeDeploy agent on the instance:")
    print("   Run: sudo bash scripts/install-codedeploy-agent.sh")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Set up EC2 instance role for CodeDeploy')
    parser.add_argument('--profile', '-p', help='AWS profile name from ~/.aws/credentials')
    args = parser.parse_args()
    main(profile=args.profile)
