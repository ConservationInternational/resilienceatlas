output "route53_zone_id" {
  value = data.aws_route53_zone.resilience_atlas_route53_zone.zone_id
}
