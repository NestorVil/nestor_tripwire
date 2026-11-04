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
