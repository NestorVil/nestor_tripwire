variable "domain_name" {
  description = "Domain whose DNS Route 53 hosts, e.g. example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a domain like example.com."
  }
}
