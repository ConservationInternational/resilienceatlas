output "route53_zone_id" {
  value = aws_route53_zone.titiler_route53_zone.zone_id
}

output "route53_zone_name_servers" {
  value = aws_route53_zone.titiler_route53_zone.name_servers
}

output "route53_domain" {
  value = local.domain
}
