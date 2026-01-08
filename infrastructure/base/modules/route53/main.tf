locals {
  domain = "${var.prefix}.${var.base_route53_zone_name}"
}

resource "aws_route53_zone" "titiler_route53_zone" {
  name = local.domain
}

resource "aws_route53_record" "histogram" {
  zone_id = aws_route53_zone.titiler_route53_zone.zone_id
  name    = "histogram.${local.domain}"
  type    = "A"
  ttl     = 300
  records = [var.gcp_lb_ip]
}

resource "aws_route53_record" "download-image" {
  zone_id = aws_route53_zone.titiler_route53_zone.zone_id
  name    = "downloadimage.${local.domain}"
  type    = "A"
  ttl     = 300
  records = [var.gcp_lb_ip]
}

resource "aws_route53_record" "raster-interaction" {
  zone_id = aws_route53_zone.titiler_route53_zone.zone_id
  name    = "rasterinteraction.${local.domain}"
  type    = "A"
  ttl     = 300
  records = [var.gcp_lb_ip]
}
