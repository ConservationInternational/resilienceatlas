TiTiler COGS Developer notes

# Important files

## TiTiler wrapper code

cloud_functions/titiler_cogs/titiler_cogs/

## SAM lambda function configuration

cloud_functions/titiler_cogs/template.yml
This file is a template for creating the lambda function

cloud_functions/titiler_cogs/samconfig.toml
This file can be used to store config parameters for sam commands, e.g. sam deploy; however, I'm not sure I managed to make it match the configuration used in the GH Actions pipeline, which is the preferred way of deployment.

## CI/CD pipeline
.github/workflows/ titiler_cogs.yaml

GH Actions workflow, generated using `sam pipeline bootstrap`. There is a different workflow when pushing to master vs pushing to a feature branch.

# AWS resources

The SAM deployment requires several resources to exist and be configured correctly (IAM user, roles, ECR image repository and build artifacts S3 bucket), and sufficient permissions to create others (CloudFormation stacks).

The file `aws_resources_for_titiler_cogs` explains about the necessary AWS resources used by the workflow.

The configuration file `template.yml` has a section for outputs, which includes the API Gateway endpoint URL for the lambda function. You can see that url in GH Actions log. This is one way to discover what the generated url is, however, since at the moment this endpoint has no authentication defined, that's a risk to have in mind. You can test that URL by appending /healthz to try the healthcheck.
