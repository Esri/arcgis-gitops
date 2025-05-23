# Copyright 2025 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "arcgis_notebook_server_patches" {
  description = "File names of ArcGIS Notebook Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_version" {
  description = "ArcGIS Enterprise version"
  type        = string
  default     = "11.5"

  validation {
    condition     = contains(["11.4", "11.5"], var.arcgis_version)
    error_message = "Valid value for arcgis_version variable are 11.4 and 11.5."
  }
}

variable "arcgis_web_adaptor_patches" {
  description = "File names of ArcGIS Web Adaptor patches to install."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region Id"
  type        = string
  default     = env("AWS_DEFAULT_REGION")
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "notebook-server-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "install_docker" {
  description = "If true, Docker will be installed on the image."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.2xlarge"
}

variable "license_level" {
  description = "ArcGIS Notebook Server license level"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "advanced"], var.license_level)
    error_message = "Valid values for license_level variable are standard and advanced."
  }
}

variable "os" {
  description = "Operating system Id (ubuntu20|ubuntu22)"
  type        = string
  default     = "ubuntu22"

  validation {
    condition     = contains(["ubuntu20", "ubuntu22"], var.os)
    error_message = "Valid values for os variable are ubuntu20 and ubuntu22."
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
  description = "User account used to run ArcGIS Notebook Server"
  type        = string
  default     = "arcgis"
}

variable "notebook_server_web_context" {
  description = "ArcGIS Web Adaptor name"
  type        = string
  default     = "notebooks"
}

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.site_id))
    error_message = "The site_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "skip_create_ami" {
  description = "If true, Packer will not create the AMI. Useful for setting to true during a build test stage."
  type        = bool
  default     = false
}
