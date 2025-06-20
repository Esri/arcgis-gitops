# Copyright 2024-2025 Esri
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
 
variable "aws_region" {
  description = "AWS region Id"
  type        = string
  default     = env("AWS_DEFAULT_REGION")
}

variable "arcgis_server_patches" {
  description = "File names of ArcGIS Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_version" {
  description = "ArcGIS Server version"
  type        = string
  default     = "11.5"

  validation {
    condition     = contains(["11.4", "11.5"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.4 and 11.5."
  }
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "server-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.2xlarge"
}

variable "os" {
  description = "Operating system Id (rhel9)"
  type        = string
  default     = "rhel9"

  validation {
    condition     = contains(["rhel9"], var.os)
    error_message = "Valid values for os variable are rhel9."
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
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.site_id))
    error_message = "The site_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "skip_create_ami" {
  description = "If true, Packer will not create the AMI. Useful for setting to true during a build test stage."
  type = bool
  default = false
}

variable "use_webadaptor" {
  description = "If true, OpenJDK, Apache Tomcat, and ArcGIS Web Adaptor will be installed on the AMI."
  type        = bool
  default     = false
}

variable "server_web_context" {
  description = "ArcGIS Web Adaptor name"
  type        = string
  default     = "arcgis"
}