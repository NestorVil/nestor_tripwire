variable "domain_name" {
  description = "Domain whose DNS zone Route 53 hosts, e.g. example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a domain like example.com."
  }
}

variable "laminar_hostname" {
  description = "Exact address Laminar is served at, inside domain_name, e.g. laminar.example.com. The certificate covers only this name."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.laminar_hostname))
    error_message = "laminar_hostname must be a host name like laminar.example.com."
  }
}
