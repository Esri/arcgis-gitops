variable "arcgis_online_password" {
  description = "ArcGIS Online user password"
  type = string
  sensitive = true
  default = null
}

variable "arcgis_online_username" {
  description = "ArcGIS Online user name"
  type = string
  default = null
}

variable "arcgis_server_patches" {
  description = "File names of ArcGIS Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_version" {
  description = "ArcGIS Server version"
  type        = string
  default     = "11.3"

  validation {
    condition     = contains(["11.2", "11.3"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.2 and 11.3."
  }
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "arcgis-server"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.2xlarge"
}

variable "os" {
  description = "Operating system Id (rhel8|rhel9)"
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
  default     = 100

  validation {
    condition     = var.root_volume_size >= 100   && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 100 and 16384."
  }
}

variable "run_as_user" {
  description = "User account used to run ArcGIS Server"
  type        = string
  default     = "arcgis"
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

variable "skip_create_ami" {
  description = "If true, Packer will not create the AMI. Useful for setting to true during a build test stage."
  type = bool
  default = false
}