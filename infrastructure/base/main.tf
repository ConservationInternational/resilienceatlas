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
  ecr_repository_arn         = module.ecr.ecr_repository_arn
  build_artifacts_bucket_arn = module.build_artifacts.build_artifacts_bucket_arn
}

module "ecr" {
  source              = "./modules/ecr"
  ecr_repository_name = "resilience-atlas-pipeline-resources"
  aws_region          = var.aws_region
}

module "build_artifacts" {
  source                   = "./modules/build_artifacts"
  bucket_name              = "${var.bucket_name_prefix}-build-artifacts"
  cloud_formation_role_arn = module.iam.cloud_formation_role_arn
  pipeline_role_arn        = module.iam.pipeline_role_arn
}

module "data_store" {
  source                   = "./modules/data_store"
  bucket_name              = "${var.bucket_name_prefix}-data"
  cloud_formation_role_arn = module.iam.cloud_formation_role_arn
  pipeline_role_arn        = module.iam.pipeline_role_arn
}

module "route53" {
  source                 = "./modules/route53"
  base_route53_zone_name = var.base_route53_zone_name
  prefix                 = var.route53_prefix
  gcp_lb_ip              = module.cloud_load_balancer.load-balancer-ip
}


module "cloud_analysis_histogram" {
  source        = "./modules/cloudfunction"
  function_name = "analysis_histogram"
  gcp_region    = var.gcp_region
  source_dir    = "${path.module}/../../cloud_functions/analysis_histogram"
  runtime       = "nodejs18"
  entry_point   = "histogram"
}

module "cloud_analysis_raster_interaction" {
  source        = "./modules/cloudfunction"
  function_name = "raster_interaction"
  gcp_region    = var.gcp_region
  source_dir    = "${path.module}/../../cloud_functions/raster_interaction"
  runtime       = "nodejs18"
  entry_point   = "rasterInteraction"
}

module "cloud_analysis_download_image" {
  source        = "./modules/cloudfunction"
  function_name = "download_image"
  gcp_region    = var.gcp_region
  source_dir    = "${path.module}/../../cloud_functions/download_image"
  runtime       = "python311"
  entry_point   = "download_image"
}

module "cloud_load_balancer" {
  source                          = "./modules/load-balancer"
  domain                          = "tt.resilienceatlas.org"
  name                            = "resilienceatlas"
  region                          = var.gcp_region
  histogram_service_name          = module.cloud_analysis_histogram.function_service_name
  download_image_service_name     = module.cloud_analysis_download_image.function_service_name
  raster_interaction_service_name = module.cloud_analysis_raster_interaction.function_service_name
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
    ARTIFACTS_BUCKET                = module.build_artifacts.bucket_name
    IMAGE_REPOSITORY                = module.ecr.ecr_repository_url
  }
  variable_map = {
    SAM_TEMPLATE = "cloud_functions/titiler_cogs/template.yaml"
    STACK_NAME   = "titiler-cogs-production"
    REGION       = var.aws_region
    FQDN         = "${var.route53_prefix}.${var.base_route53_zone_name}"
  }
}
