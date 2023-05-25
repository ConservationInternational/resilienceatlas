output "route53_zone_name_servers" {
  value = module.route53.route53_zone_name_servers
}

output "pipeline_user_access_key_id" {
  value = module.iam.pipeline_user_access_key_id
  sensitive = true
}

output "pipeline_user_secret_access_key" {
  value = module.iam.pipeline_user_access_key_secret
  sensitive = true
}

output "pipeline_execution_role" {
  value = module.iam.pipeline_role_arn
  sensitive = true
}
