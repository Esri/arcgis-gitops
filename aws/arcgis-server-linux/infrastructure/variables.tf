variable "client_cidr_blocks" {
  description = "Client CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for b in var.client_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in vpc_cidr_block list must be in IPv4 CIDR block format."
  }
}

variable "deployment_fqdn" {
  description = "Fully qualified domain name of the ArcGIS Server deployment"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn)) || var.deployment_fqdn == null
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "deployment_id" {
  description = "ArcGIS Server deployment Id"
  type        = string
  default     = "arcgis-server"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "hosted_zone_id" {
  description = "The Route 53 hosted zone ID for the deployment FQDN"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^Z[0-9A-Z]{14,}$", var.hosted_zone_id)) || var.hosted_zone_id == null
    error_message = "The hosted_zone_id value must be a valid Route 53 hosted zone ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.2xlarge"
}

variable "internal_load_balancer" {
  description = "If true, the load balancer scheme is set to 'internal'"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "node_count" {
  description = "Number of node EC2 instances"
  type        = number
  default     = 1
}

variable "os" {
  description = "Operating system id (rhel8|rhel9)"
  type        = string
  default     = "rhel8"

  validation {
    condition     = contains(["rhel8", "rhel9"], var.os)
    error_message = "Valid values for os variable are rhel8 and rhel9."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 1024

  validation {
    condition     = var.root_volume_size >= 100 && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 100 and 16384."
  }
}

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
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

variable "subnet_ids" {
  description = "EC2 instances subnet IDs (by default, the first two private VPC subnets are used)"
  type        = list(string)
  default     = []
}