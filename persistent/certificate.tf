resource "aws_acm_certificate" "laminar" {
  domain_name       = var.laminar_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = endswith(var.laminar_hostname, ".${var.domain_name}")
      error_message = "laminar_hostname must be inside domain_name, e.g. laminar.example.com for example.com."
    }
  }
}

resource "aws_route53_record" "laminar_certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.laminar.domain_validation_options :
    option.domain_name => option
  }

  zone_id         = aws_route53_zone.main.zone_id
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  ttl             = 300
  records         = [each.value.resource_record_value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "laminar" {
  certificate_arn         = aws_acm_certificate.laminar.arn
  validation_record_fqdns = [for record in aws_route53_record.laminar_certificate_validation : record.fqdn]
}

output "certificate_arn" {
  description = "Issued certificate for laminar_hostname, used by the load balancer."
  value       = aws_acm_certificate_validation.laminar.certificate_arn
}

