terraform {
  backend "s3" {
    // TF does not allow vars here. Use the value from var.terraform_state_bucket from the state project
    bucket = "resilience-atlas-terraform-state"
    key    = "state"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
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
  cloud_formation_role_arn = module.iam.cloud_formation_role_arn
  pipeline_role_arn        = module.iam.pipeline_role_arn
}
