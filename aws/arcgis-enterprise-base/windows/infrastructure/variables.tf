variable "os" {
  description = "Operating system id (windows2022)"
  type        = string
  default     = "windows2022"
}

variable "site_id" {
  description = "ArcGIS site Id"
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
  default     = "arcgis-enterprise-base"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }  
}

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

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for HTTPS listener of the load balancer"
  type        = string

  validation {
    condition     = can(regex("^arn:.+:acm:.+:\\d+:certificate\\/.+$", var.ssl_certificate_arn))
    error_message = "The ssl_certificate_arn value must be an ACM certificate ARN."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.2xlarge"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB of primary and standby EC2 instances"
  type        = number
  default     = 1024
  
  validation {
    condition     = var.root_volume_size >= 100   && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 100 and 16384."
  }    
}

variable "fileserver_instance_type" {
  description = "EC2 instance type of fileserver"
  type        = string
  default     = "m6i.xlarge"
}

variable "fileserver_volume_size" {
  description = "Root EBS volume size in GB of fileserver EC2 instance"
  type        = number
  default     = 100

  validation {
    condition     = var.fileserver_volume_size >= 100   && var.fileserver_volume_size <= 16384
    error_message = "The fileserver_volume_size value must be between 100 and 16384."
  }    
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "subnet_type" {
  description = "Type of the EC2 instances subnets. Valid values are public, private, and isolated. Default is private."
  type        = string
  default     = "private"
  validation {
    condition     = contains(["public", "private", "isolated"], var.subnet_type)
    error_message = "Valid values for the subnet_type variable are public, private, and isolated"
  }
}
