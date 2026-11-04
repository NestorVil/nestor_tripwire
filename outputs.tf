output "laminar_url" {
  description = "Laminar dashboard."
  value       = local.laminar_url
}

output "sdk_base_url" {
  description = "Base URL for Laminar SDKs."
  value       = "https://${local.hostnames.api}"
}
