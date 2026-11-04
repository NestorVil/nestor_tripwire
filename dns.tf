locals {
  hostnames = {
    laminar = "laminar.${var.domain_name}"
    api     = "api.${var.domain_name}"
  }
}

data "aws_route53_zone" "main" {
  name = var.domain_name
}

data "aws_acm_certificate" "wildcard" {
  domain      = "*.${var.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_route53_record" "alb" {
  for_each = local.hostnames

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
