resource "aws_route53_zone" "titiler_route53_zone" {
  name = "${var.prefix}.${var.base_route53_zone_name}"
}
