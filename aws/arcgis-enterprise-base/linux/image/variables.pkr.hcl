variable "os" {
  description = "Operating system Id (rhel8|rhel9|ubuntu20|ubuntu22|sles15)"
  type        = string
  default     = "rhel8"

  validation {
    condition     = contains(["rhel8", "rhel9", "ubuntu20", "ubuntu22", "sles15"], var.os)
    error_message = "Valid values for os variable are rhel8, rhel9, ubuntu20, ubuntu22, and sles15."
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

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "arcgis-enterprise-base"

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

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 100   && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 100 and 16384."
  }
}

variable "arcgis_version" {
  description = "ArcGIS Enterprise version"
  type        = string
  default     = "11.2"

  validation {
    condition     = contains(["11.0", "11.1", "11.2"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.0, 11.1, and 11.2."
  }
}

variable "run_as_user" {
  description = "User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store"
  type        = string
  default     = "arcgis"
}

variable "java_version" {
  description = "OpenJDK version"
  type        = string
  default    = "11.0.20"
}

variable "tomcat_version" {
  description = "Apache Tomcat version"
  type        = string
  default     = "9.0.48"
}

variable "arcgis_portal_patches" {
  description = "File names of Portal for ArcGIS patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_server_patches" {
  description = "File names of ArcGIS Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_data_store_patches" {
  description = "File names of ArcGIS Data Store patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_web_adaptor_patches" {
  description = "File names of ArcGIS Web Adaptor patches to install."
  type        = list(string)
  default     = []
}

variable "skip_create_ami" {
  description = "If true, Packer will not create the AMI. Useful for setting to true during a build test stage."
  type = bool
  default = false
}

variable "arcgis_online_username" {
  description = "ArcGIS Online user name"
  type = string
  default = null
}

variable "arcgis_online_password" {
  description = "ArcGIS Online user password"
  type = string
  sensitive = true
  default = null
}
