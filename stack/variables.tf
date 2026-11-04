variable "name_prefix" {
  description = "Prefix for AWS resource names, so several deployments can share one account."
  type        = string
  default     = "tripwire"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.name_prefix))
    error_message = "name_prefix must be 2-21 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "allowed_cidrs" {
  description = "IP ranges allowed to reach the load balancer, e.g. [\"203.0.113.7/32\"]. The dashboard login is open, so keep this narrow."
  type        = list(string)

  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for cidr in var.allowed_cidrs : can(cidrhost(cidr, 0))])
    error_message = "allowed_cidrs must be a non-empty list of CIDR ranges like \"203.0.113.7/32\"."
  }
}

variable "domain_name" {
  description = "Domain of the Route 53 zone created in persistent/, e.g. example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a domain like example.com."
  }
}

variable "laminar_hostname" {
  description = "Exact address Laminar is served at, e.g. laminar.example.com. Its certificate is created in persistent/."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9-]+\\.)+[a-z]{2,}$", var.laminar_hostname))
    error_message = "laminar_hostname must be a host name like laminar.example.com."
  }
}
