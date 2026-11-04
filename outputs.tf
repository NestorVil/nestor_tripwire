output "laminar_url" {
  description = "Laminar dashboard. SDKs use the same address with port 80 and force_http=True."
  value       = "http://${aws_lb.main.dns_name}"
}
