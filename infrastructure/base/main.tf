terraform {
  backend "s3" {
    // TF does not allow vars here. Use the value from var.terraform_state_bucket from the state project
    bucket = "resilienceatlas-terraform-state"
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
  bucket_name              = var.build_artifacts_bucket_name
  cloud_formation_role_arn = module.iam.cloud_formation_role_arn
  pipeline_role_arn        = module.iam.pipeline_role_arn
}

module "route53" {
  source                 = "./modules/route53"
  base_route53_zone_name = var.base_route53_zone_name
  prefix                 = var.route53_prefix
}

module "github_values" {
 source     = "./modules/github_values"
 repo_name  = var.github_repo_name
 secret_map = {
   PIPELINE_USER_ACCESS_KEY_ID     = module.iam.pipeline_user_access_key_id
   PIPELINE_USER_SECRET_ACCESS_KEY = module.iam.pipeline_user_access_key_secret
   ROUTE53_ZONE_ID                 = module.route53.route53_zone_id
   PIPELINE_EXECUTION_ROLE         = module.iam.pipeline_role_arn
   CLOUDFORMATION_EXECUTION_ROLE   = module.iam.cloud_formation_role_arn
   ARTIFACTS_BUCKET                = var.build_artifacts_bucket_name
   IMAGE_REPOSITORY                = module.ecr.pipeline_resources_url
 }
 variable_map = {
   SAM_TEMPLATE = "cloud_functions/titiler_cogs/template.yaml"
   STACK_NAME   = "titiler-cogs-production"
   REGION       = var.aws_region
   FQDN         = "${var.route53_prefix}.${var.base_route53_zone_name}"
 }
}
