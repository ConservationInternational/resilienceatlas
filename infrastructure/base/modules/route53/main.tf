data "aws_route53_zone" "resilience_atlas_route53_zone" {
  name = var.route53_zone_name
}
