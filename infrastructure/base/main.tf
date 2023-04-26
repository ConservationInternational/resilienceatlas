terraform {
  backend "s3" {
    // TF does not allow vars here. Use the value from var.terraform_state_bucket from the state project
    bucket = "resilience-atlas-terraform-state"
    key    = "state"
    region = "us-east-1"
  }
}

module "iam" {
  source                     = "./modules/iam"
  pipeline_resources_arn     = module.ecr.pipeline_resources_arn
  build_artifacts_bucket_arn = module.s3.build_artifacts_bucket_arn
}

module "ecr" {
  source = "./modules/ecr"
}

module "s3" {
  source                   = "./modules/s3"
  bucket_name              = "resilience-atlas-build-artifacts"
  cloud_formation_role_arn = module.iam.cloud_formation_role_arn
  pipeline_role_arn        = module.iam.pipeline_role_arn
}

module "github_secrets" {
  source     = "./modules/github_secrets"
  repo_name  = "resilienceatlas"
  secret_map = {
    PIPELINE_USER_ACCESS_KEY_ID           = module.iam.pipeline_user_access_key_id
    PIPELINE_USER_SECRET_ACCESS_KEY       = module.iam.pipeline_user_access_key_secret
    SAM_TEMPLATE                          = "cloud_functions/titiler_cogs/template.yaml"
    TESTING_STACK_NAME                    = "titiler-cogs-staging"
    TESTING_PIPELINE_EXECUTION_ROLE       = module.iam.pipeline_role_arn
    TESTING_CLOUDFORMATION_EXECUTION_ROLE = module.iam.cloud_formation_role_arn
    TESTING_ARTIFACTS_BUCKET              = var.bucket_name
    TESTING_IMAGE_REPOSITORY              = module.ecr.pipeline_resources_url
    TESTING_REGION                        = var.aws_region
    PROD_STACK_NAME                       = "titiler-cogs-production"
    PROD_PIPELINE_EXECUTION_ROLE          = module.iam.pipeline_role_arn
    PROD_CLOUDFORMATION_EXECUTION_ROLE    = module.iam.cloud_formation_role_arn
    PROD_ARTIFACTS_BUCKET                 = var.bucket_name
    PROD_IMAGE_REPOSITORY                 = module.ecr.pipeline_resources_url
    PROD_REGION                           = var.aws_region
  }
}
