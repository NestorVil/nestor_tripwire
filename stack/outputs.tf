output "laminar_url" {
  description = "Laminar dashboard, and the SDK base_url: HTTP on 443, gRPC on 8443 (the SDK defaults)."
  value       = local.laminar_url
}
