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

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment Id"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "machine_roles" {
  description = "List of machine roles."
  type = list(string)
}   

variable json_attributes {
  description = "Configuration parameters in JSON format"
  type = string
  sensitive = true
}

variable "install_mode" {
  description = "Installation mode"
  type = string
  default = "InstallLicenseConfigure"

  validation {
    condition     = can(regex("^(Install|InstallLicense|InstallLicenseConfigure|Uninstall|Upgrade)$", var.install_mode))
    error_message = "The install_mode value must be 'Install', 'InstallLicense', 'InstallLicenseConfigure', 'Uninstall', or 'Upgrade'."
  }
}

variable "execution_timeout" {
  description = "Timeout in seconds"
  type = number
  default = 3600 # 1 hour
}
