resource "aws_route53_zone" "main" {
  name = var.domain_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53domains_registered_domain" "main" {
  domain_name = var.domain_name
  auto_renew  = false

  dynamic "name_server" {
    for_each = aws_route53_zone.main.name_servers

    content {
      name = name_server.value
    }
  }
}

output "name_servers" {
  description = "Name servers of the hosted zone."
  value       = aws_route53_zone.main.name_servers
}
