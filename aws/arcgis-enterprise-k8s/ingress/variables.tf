variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment Id"
  type        = string
  default     = "arcgis-enterprise-k8s"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "internal_load_balancer" {
  description = "If true, the load balancer scheme is set to 'internal'"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for HTTPS listeners of the load balancer"
  type        = string

  validation {
    condition     = can(regex("^arn:.+:acm:.+:\\d+:certificate\\/.+$", var.ssl_certificate_arn))
    error_message = "The ssl_certificate_arn value must be an ACM certificate ARN."
  }
}

variable "ssl_policy" {
  description = "Security Policy that should be assigned to the ALB to control the SSL protocol and ciphers"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "deployment_fqdn" {
  description = "The fully qualified domain name (FQDN) to access ArcGIS Enterprise on Kubernetes"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn))
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "arcgis_enterprise_context" {
  description = "Context path to be used in the URL for ArcGIS Enterprise on Kubernetes"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9]{1,}$", var.arcgis_enterprise_context))
    error_message = "The arcgis_enterprise_context value must be an alphanumeric string."
  }
}

variable "hosted_zone_id" {
  description = "The Route 53 hosted zone ID for the domain"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^Z[0-9A-Z]{14,}$", var.hosted_zone_id)) || var.hosted_zone_id == null
    error_message = "The hosted_zone_id value must be a valid Route 53 hosted zone ID."
  }
}