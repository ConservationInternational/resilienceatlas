# Infrastructure

This folder includes the [Terraform](https://www.terraform.io/) code that you can use to create resources
in [Amazon Web Services](https://aws.amazon.com/), which are required for automated deployment of the COG
tiler [TiTiler](https://developmentseed.org/titiler/) as a lambda function.

It does not cover the infrastructure required for the frontend and backend applications.

## Dependencies

This deployment workflow relies on the coordination of different tools and services to work. If you wish to deploy it
to your infrastructure, you must:

- Be conformable with using and have installed [Terraform](https://www.terraform.io/) v1.4.5
- Be familiar with [Github Actions](https://github.com/features/actions) and a Github API Key with permissions to
  manipulate secrets.
- Have configured the [AWS CLI](https://aws.amazon.com/cli/) with access to the desired AWS account.

Additionally, if you'd like to modify the behaviour of the infrastructure and workflows, you will need to be familiar
with the following:

- [Amazon Web Services](https://aws.amazon.com/)
    - [IAM](https://aws.amazon.com/iam/)
    - [S3](https://aws.amazon.com/s3/)
    - [ECR](https://aws.amazon.com/ecr/)
    - [Lambda](https://aws.amazon.com/lambda/)
    - [API Gateway](https://aws.amazon.com/api-gateway/)
    - [CloudFormation](https://aws.amazon.com/cloudformation/)
    - [Route53](https://aws.amazon.com/route53/)
- [AWS Serverless Application Model](https://aws.amazon.com/serverless/sam/)
- [Docker](https://www.docker.com/)

## Structure and how to deploy

The deployment process is split into multiple steps, and while it's not complex in its nature, it does require some
manual steps along the way, so its strongly recommended that you read this document in its entirety before proceeding.

We'll go into the details of each of them, but here is how the infrastructure components are structured:

- Within the `infrastructure` directory there are two subdirectories, `state` and `base`, each containing a separate
  Terraform project.
- Within the `.github` repository there are GH Actions workflows for automatically building and deploying the TiTiler
  lambda function.
- Within the `cloud_functions` directory there is `titiler_cogs` subdirectory, which contains the TiTiler application
  and SAM configuration for building and deploying the TiTiler lambda function.

#### The `state` Terraform project

This project simply creates an S3 bucket that will store the Terraform state of the `base` project. Due to limitations
in Terraform itself, the bucket name is hardcoded (`state/main.tf`, `aws_s3_bucket` resource), and you will need to
modify it before proceeding. Once created, the bucket will be used by the `base` project to store its state.

#### The `base` Terraform project

This project sets up the necessary AWS resources needed for automated deployment of the TiTiler as a lambda function.

These resources include, among other things:

- an S3 bucket that will store build artifacts
- an ECR repository that will store the lambda Docker image
- an IAM role used for building the image and uploading it to ECR
- an IAM role used for creating a CloudFormation stack and deploying to it
- several Github secrets and variables that will be used by the Github Actions workflows

Before applying this project, you will need to modify the name of the S3 bucket used to store the
state (`base/main.tf`, `terraform` -> `backend` element). Use the name of the S3 bucket created in the `state`
project. You will also need to have created, beforehand, a Route53 hosted zone for the domain you wish to use for the
application. You'll be prompted to enter the name of the hosted zone when applying the project as a Terraform variable.

Due
to [a limitation in the Terraform provider for Github](https://github.com/integrations/terraform-provider-github/issues/667#issuecomment-1182340862),
you will need to manually set the following environment variables when applying this Terraform project:

- `GITHUB_OWNER`: the name of the Github organisation or user that owns the repository.
- `GITHUB_TOKEN` : a Github API token with permissions to manipulate secrets.

To apply this project, you will need the following AWS IAM permissions:

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

#### The Github Actions workflows

As part of this infrastructure, GitHub Actions are used to detect changes to the TiTiler configuration, and
automatically build and deploy them to AWS, on a per-branch basis. There is also a workflow in place to clean up said
per-branch deployments once the corresponding branch has been deleted from Github (except for the `master` branch).

These Github Actions will rely on several Github secrets and variables set by the Terraform `base` project, which
include AWS access credentials and other sensitive information.

#### The TiTiler configuration code

The TiTiler wrapper code is contained in the `cloud_functions/titiler_cogs/` subdirectory, and the corresponding AWS
SAM deployment template is stored in `template.yaml`. It is configured to set up a lambda function, accessible through a
public a REST API URL, using a custom branch-based subdomain of the domain you specified when applying the
Terraform `base` project.

### Deployment guide

Hopefully you've read all the details above, and are now ready to deploy the infrastructure. Here are the steps you'll
need to follow:

- Have a Route53 hosted zone for the domain you wish to use for the TiTiler public URL.
- Modify both `base/main.tf` and `state/main.tf` files to set the name of the S3 bucket that will store the Terraform
  state.
- Apply the `state` and `base` Terraform projects, in that order. Be sure to set the necessary environment variables
  when applying the `base` project.
- Trigger the Github Actions workflow by either pushing changes to the TiTiler cloud function.
