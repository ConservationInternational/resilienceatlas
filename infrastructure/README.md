# Infrastructure

This project includes a [Terraform](https://www.terraform.io/) project
that you can use to create resources in [Amazon Web Services](https://aws.amazon.com/), which are required for automated deployment of the COG tiler [TiTiler](https://developmentseed.org/titiler/) as a lambda function.

## Dependencies

Here is the list of technical dependencies for preparing the infrastructure using the terraform script.

- [Amazon Web Services](https://aws.amazon.com/)
  - [IAM](https://aws.amazon.com/iam/?nc2=type_a)
  - [S3](https://aws.amazon.com/s3/?nc2=h_ql_prod_st_s3)
  - [ECR](https://aws.amazon.com/ecr/?nc2=h_ql_prod_ct_ec2reg)
  - [Lambda](https://aws.amazon.com/lambda/?nc2=h_ql_prod_fs_lbd)
  - [API Gateway](https://aws.amazon.com/api-gateway/?nc2=h_ql_prod_nt_apig)
  - [CloudFormation](https://aws.amazon.com/cloudformation/?nc2=type_a)
  - [Route53](https://aws.amazon.com/route53/?nc2=type_a)
- [AWS Serverless Application Model](https://aws.amazon.com/serverless/sam/)
- [Terraform](https://www.terraform.io/)
- [Docker](https://www.docker.com/)
- [Github Actions](https://github.com/features/actions)

## Structure

- Within the `infrastructure` directory there are two subdirectories, `state` and `base`, each containing a separate Terraform project
- Within the `cloud_functions` directory there is `titiler_cogs` subdirectory, which contains the TiTiler application and SAM configuration for building and deploying the TiTiler lambda function
- Within the .github repository there is a GH Actions workflow for automatically building and deploying the TiTiler lambda function

#### infrastructure / state

Creates an S3 bucket that will store the Terraform state of the `base` project.

#### infrastructure / base

Sets up multiple AWS resources needed for automated deployment of the TiTiler as a lambda function.

These resources include:

- an S3 bucket that will store build artifacts
- an ECR repository that will store the lambda image
- an IAM role used for building the image and uploading it to ECR
- an IAM role used for creating a CloudFormation stack and deploying to it

To apply this project, you will need the following AWS permissions:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "iam:DeleteAccessKey",
                "route53:GetHostedZone",
                "iam:CreateRole",
                "s3:CreateBucket",
                "iam:PutRolePolicy",
                "ecr:DeleteRepository",
                "s3:GetBucketObjectLockConfiguration",
                "iam:ListAttachedRolePolicies",
                "s3:PutBucketAcl",
                "ecr:TagResource",
                "iam:ListRolePolicies",
                "s3:GetBucketPolicyStatus",
                "iam:GetRole",
                "s3:GetBucketWebsite",
                "ecr:CreateRepository",
                "iam:DeleteUserPolicy",
                "iam:DeleteRole",
                "ecr:GetAuthorizationToken",
                "s3:GetBucketNotification",
                "s3:DeleteBucketPolicy",
                "s3:GetReplicationConfiguration",
                "route53:ListTagsForResources",
                "s3:PutObject",
                "s3:GetObject",
                "iam:GetUserPolicy",
                "iam:ListGroupsForUser",
                "iam:GetRolePolicy",
                "s3:GetLifecycleConfiguration",
                "s3:GetBucketTagging",
                "iam:UntagRole",
                "iam:TagRole",
                "s3:GetBucketLogging",
                "s3:ListBucket",
                "s3:GetAccelerateConfiguration",
                "ecr:ListTagsForResource",
                "iam:CreateUser",
                "s3:GetBucketPolicy",
                "iam:CreateAccessKey",
                "iam:ListInstanceProfilesForRole",
                "s3:GetEncryptionConfiguration",
                "s3:GetBucketRequestPayment",
                "iam:DeleteRolePolicy",
                "s3:GetBucketOwnershipControls",
                "ecr:DescribeRepositories",
                "s3:DeleteBucket",
                "iam:ListAccessKeys",
                "s3:GetBucketPublicAccessBlock",
                "route53:ListHostedZones",
                "iam:DeleteUser",
                "s3:GetBucketVersioning",
                "s3:GetBucketAcl",
                "iam:TagUser",
                "route53:ListTagsForResource",
                "iam:UntagUser",
                "iam:PutUserPolicy",
                "s3:GetBucketCORS",
                "s3:PutBucketPolicy",
                "iam:GetUser",
                "s3:GetBucketLocation"
            ],
            "Resource": "*"
        }
    ]
}
```

And the following local variables provided:

```
allowed_account_id = "XXXXXXXXXXXX" # AWS account number
bucket_name        = "resilience-atlas-build-artifacts" # name of bucket for stori
route53_zone_name  = "zone.example.com"
github_repo_name   = "resilienceatlas"
```

The output values include access data for some of the resources above. Some values are automatically injected into GH Actions secrets.

#### cloud_functions / titiler_cogs

The TiTiler wrapper code is contained in the `titiler_cogs` subdirectory, while the SAM deployment template is stored in `template.yaml`. It is configured to set up a lambda function with a REST API Gateway, using a custom branch-based domain.

#### .github / workflows / titiler_cogs.yaml

As part of this infrastructure, GitHub Actions are used to automatically build and push Docker images to ECR, and to deploy those images to a CloudFormation stack. GH Actions uses `sam` commands for the build and deploy steps.

## How to deploy

Deploying the included Terraform project is done in steps:

- Terraform `apply` the `state` project.
- Terraform `apply` the `base` project.
- Trigger the Github Actions workflow by either pushing changes to the TiTiler cloud function, to the workflow or using a manual trigger.
