AWS SAM was used to create the resources needed for hosting and automated deployment of the lambda function. The following instructions should help with recreating the required resources in the target AWS account.

# ECR repositories

## resilience-atlas-pipeline-resources

Create a new repository with default settings called resilience-atlas-pipeline-resources

OUTPUT: ARN of the created resource

# S3 buckets

## resilience-atlas-build-artifacts

Create a new S3 bucket, uncheck the "Block all public access" checkbox

Once created, in the permissions tab paste the following bucket policy:

```
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::resilience-atlas-build-artifacts/*",
                "arn:aws:s3:::resilience-atlas-build-artifacts"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::744899542263:role/resilience-atlas-CloudFormationExecutionRole",
                    "arn:aws:iam::744899542263:role/resilience-atlas-PipelineExecutionRole"
                ]
            },
            "Action": [
                "s3:GetObject*",
                "s3:PutObject*",
                "s3:GetBucket*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::resilience-atlas-build-artifacts/*",
                "arn:aws:s3:::resilience-atlas-build-artifacts"
            ]
        }
    ]
}
```

OUTPUT: ARN of the created resource

# Roles

## resilience-atlas-CloudFormationExecutionRole

This role is used in the automated deployment process. It needs permissions for CloudFormation, as it manages the resources.

To create it in the AWS console, use "create role":
- in the first step, trusted entity, select custom trust policy and paste the following:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "cloudformation.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

In the second step, permissions, click next - permissions will be defined as an inline policy.

In the third step, no tags are needed.

Once role is created, on the permissions tab use the "create inline policy" button and paste the following in the JSON editor to create an inline policy called GrantCloudFormationFullAccess

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "*",
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
```

OUTPUT: ARN of the created resource

## resilience-atlas-PipelineExecutionRole

This role is used in the automated deployment process. It needs permissions for ECR, S3, CloudFormation and IAM, as it manages the resources.

TODO: aws-sam-pipeline-codebuild-service-role

To create it in the AWS console, use "create role":
- in the first step, trusted entity, select custom trust policy and paste the following:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::744899542263:user/resilience-atlas-PipelineUser"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::744899542263:root"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "aws:PrincipalTag/Role": "aws-sam-pipeline-codebuild-service-role"
                }
            }
        }
    ]
}
```

In the second step, permissions, click next - permissions will be defined as an inline policy.

In the third step, add a tag:
`Role  pipeline-execution-role`

Once role is created, on the permissions tab use the "create inline policy" button and paste the following in the JSON editor to create an inline policy called `PipelineExecutionRolePermissions`

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::744899542263:role/resilience-atlas-CloudFormationExecutionRole",
            "Effect": "Allow"
        },
        {
            "Action": [
                "cloudformation:CreateChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStackEvents",
                "cloudformation:DescribeStacks",
                "cloudformation:GetTemplate",
                "cloudformation:GetTemplateSummary",
                "cloudformation:DescribeStackResource"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:DeleteObject",
                "s3:GetObject*",
                "s3:PutObject*",
                "s3:GetBucket*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::resilience-atlas-build-artifacts/*",
                "arn:aws:s3:::resilience-atlas-build-artifacts"
            ],
            "Effect": "Allow"
        },
        {
            "Action": "ecr:GetAuthorizationToken",
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchDeleteImage",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "arn:aws:ecr:us-east-1:744899542263:repository/resilience-atlas-pipeline-resources-imagerepository",
            "Effect": "Allow"
        }
    ]
}
```

OUTPUT: ARN of the created resource

# Users

## resilience-atlas-PipelineUser

Create new user resilience-atlas-PipelineUser (no console access), skip permissions. Once created, go to permissions tab and select "create inline policy".

Paste the following in the JSON editor and name the policy `AssumeRoles`:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/Role": "pipeline-execution-role"
                }
            },
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
```

Next, under "security credentials" -> "Access keys", click "create access key". in the first step, select "third party service". The description is "Resilience Atlas GH Actions auto deploy". In the final step please take note of the access key and secret or download the csv file with the key to share with Vizz.

OUTPUTS:
- ARN of the created resource
- access key / secret


# For terraform

## Create a user to run terraform scripts

resilience-atlas-TerraformUser

And generate an access key (for the Command Line Interface)

This user requires the following permissions: TODO
