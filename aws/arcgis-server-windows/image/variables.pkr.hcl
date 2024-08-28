# Copyright 2024 Esri
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
  description = "Operating system Id"
  type = string
  default = "windows2022"

  validation {
    condition     = contains(["windows2022"], var.os)
    error_message = "Valid values for os variable are windows2022."
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

variable "run_as_password" {
  description = "Password for the account used to run ArcGIS Server"
  type        = string
  sensitive   = true
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

variable "install_webadaptor" {
  description = "If true, ArcGIS Web Adaptor (IIS) will be installed on the AMI."
  type        = bool
  default     = false
}

variable "webadaptor_name" {
  description = "ArcGIS Web Adaptor name"
  type        = string
  default     = "arcgis"
}
