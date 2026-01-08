# Infrastructure

This folder includes the [Terraform](https://www.terraform.io/) code that you can use to create resources
in [Amazon Web Services](https://aws.amazon.com/), which are required for automated deployment of the COG
tiler [TiTiler](https://developmentseed.org/titiler/) as a lambda function.

It does not cover the infrastructure required for the frontend and backend applications.

## Dependencies

This deployment workflow relies on the coordination of different tools and services to work. If you wish to deploy it
to your infrastructure, you must:

- Be conformable with using and have installed [Terraform](https://www.terraform.io/) v1.4.5
- Be familiar with [GitHub Actions](https://github.com/features/actions) and a Github API Key with permissions to
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
                "ecr:CreateRepository",
                "ecr:DeleteRepository",
                "ecr:DescribeRepositories",
                "ecr:GetAuthorizationToken",
                "ecr:ListTagsForResource",
                "ecr:TagResource",
                "iam:CreateAccessKey",
                "iam:CreateRole",
                "iam:CreateUser",
                "iam:DeleteAccessKey",
                "iam:DeleteRole",
                "iam:DeleteRolePolicy",
                "iam:DeleteUser",
                "iam:DeleteUserPolicy",
                "iam:GetRole",
                "iam:GetRolePolicy",
                "iam:GetUser",
                "iam:GetUserPolicy",
                "iam:ListAccessKeys",
                "iam:ListAttachedRolePolicies",
                "iam:ListGroupsForUser",
                "iam:ListInstanceProfilesForRole",
                "iam:ListRolePolicies",
                "iam:PutRolePolicy",
                "iam:PutUserPolicy",
                "iam:TagRole",
                "iam:TagUser",
                "iam:UntagRole",
                "iam:UntagUser",
                "route53:GetHostedZone",
                "route53:ListHostedZones",
                "route53:ListTagsForResource",
                "route53:ListTagsForResources",
                "s3:CreateBucket",
                "s3:DeleteBucket",
                "s3:DeleteBucketPolicy",
                "s3:GetAccelerateConfiguration",
                "s3:GetBucketAcl",
                "s3:GetBucketCORS",
                "s3:GetBucketLocation",
                "s3:GetBucketLogging",
                "s3:GetBucketNotification",
                "s3:GetBucketObjectLockConfiguration",
                "s3:GetBucketOwnershipControls",
                "s3:GetBucketPolicy",
                "s3:GetBucketPolicyStatus",
                "s3:GetBucketPublicAccessBlock",
                "s3:GetBucketRequestPayment",
                "s3:GetBucketTagging",
                "s3:GetBucketVersioning",
                "s3:GetBucketWebsite",
                "s3:GetEncryptionConfiguration",
                "s3:GetLifecycleConfiguration",
                "s3:GetObject",
                "s3:GetReplicationConfiguration",
                "s3:ListBucket",
                "s3:PutBucketAcl",
                "s3:PutBucketPolicy",
                "s3:PutObject"
            ],
            "Resource": "*"
        }
    ]
}
```

Note: Applying the `base` Terraform project will create an IAM role and user that will be made available to the Github
Action workflows, and will be used to build and deploy the TiTiler lambda function. For details on the permissions
granted to this role, see the `base` Terraform project source code.

#### The Github Actions workflows

As part of this infrastructure, GitHub Actions are used to detect changes to the TiTiler configuration, and
automatically build and deploy them to AWS, on a per-branch basis. There is also a workflow in place to clean up said
per-branch deployments once the corresponding branch has been deleted from Github (except for the `main` branch).

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
