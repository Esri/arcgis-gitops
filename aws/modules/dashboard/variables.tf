variable "platform" {
  description = "Deployment platform (windows|linux)"
  type        = string
  default     = "windows"

  validation {
    condition     = can(regex("^(windows|linux)$", var.platform))
    error_message = "The platform value must be either 'windows' or 'linux'."
  }
}

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment Id"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "alb_arn" {
  description = "ARN of Application Load Balancer"
  type        = string
  default     = null
}

variable "log_group_name" {
  description = "CloudWatch log group name"
  type        = string
}
