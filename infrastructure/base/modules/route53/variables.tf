variable "base_route53_zone_name" {
  type        = string
  description = "The name of the existing Route53 zone to use as base for the titiler DNS records."
}

variable "prefix" {
  type        = string
  description = "Prefix to use for the Route53 zone created by this module. Will be prepended to the existing zone name."
}

variable "gcp_lb_ip" {
  type        = string
  description = "The IP address of the GCP load balancer to use for the DNS records."
}
