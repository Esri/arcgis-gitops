# Copyright 2026 Esri
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

variable "arcgis_data_store_patches" {
  description = "File names of ArcGIS Data Store patches to install."
  type        = list(string)
  default     = []
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

variable "arcgis_version" {
  description = "ArcGIS Enterprise version"
  type        = string
  default     = "12.0"

  validation {
    condition     = contains(["11.4", "11.5", "12.0"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.4, 11.5, and 12.0."
  }
}

variable "azure_cli_version" {
  description = "Version of Azure CLI to install on the image"
  type        = string
  default     = "2.76.0"
}

variable "azure_region" {
  description = "Azure region display name"
  type        = string
  default     = env("AZURE_DEFAULT_REGION")
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "enterprise-base-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "os" {
  description = "Operating system Id (rhel9|ubuntu24)"
  type        = string
  default     = "rhel9"

  validation {
    condition     = contains(["rhel9", "ubuntu24"], var.os)
    error_message = "Valid values for os variable are rhel9 and ubuntu24."
  }
}

variable "os_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 256

  validation {
    condition     = var.os_disk_size >= 100 && var.os_disk_size <= 16384
    error_message = "The os_disk_size value must be between 100 and 16384."
  }
}

variable "portal_web_context" {
  description = "Portal for ArcGIS web context"
  type        = string
  default     = "portal"
}

variable "run_as_user" {
  description = "User account used to run ArcGIS Enterprise"
  type        = string
  default     = "arcgis"
}

variable "server_web_context" {
  description = "ArcGIS Server web context"
  type        = string
  default     = "server"
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

variable "skip_create_image" {
  description = "If true, Packer will not create the VM image. Useful for setting to true during a build test stage."
  type        = bool
  default     = false
}

variable "vault_name" {
  description = "Name of the Azure Key Vault"
  type        = string
}

variable "vm_size" {
  description = "Size of the source VM used to build the image"
  type        = string
  default     = "Standard_D8s_v5"
}
