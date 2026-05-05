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

variable "arcgis_notebook_server_patches" {
  description = "File names of ArcGIS Notebook Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_version" {
  description = "ArcGIS Enterprise version"
  type        = string
  default     = "12.0"

  validation {
    condition     = contains(["11.4", "11.5", "12.0"], var.arcgis_version)
    error_message = "Valid value for arcgis_version variable are 11.4, 11.5, and 12.0."
  }
}

variable "arcgis_web_adaptor_patches" {
  description = "File names of ArcGIS Web Adaptor patches to install."
  type        = list(string)
  default     = []
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
  description = "Deployment ID"
  type        = string
  default     = "notebook-server-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "docker_version" {
  description = "Version of Docker CE to install on the image"
  type        = string
  default     = "28.5.2"
}

variable "enterprise_id" {
  description = "ArcGIS Enterprise ID"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.enterprise_id))
    error_message = "The enterprise_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "gpu_ready" {
  description = "If true, the image is built with GPU support"
  type        = bool
  default     = false
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

variable "notebook_server_web_context" {
  description = "ArcGIS Web Adaptor name"
  type        = string
  default     = "notebooks"
}

variable "os" {
  description = "Operating system ID (rhel9|ubuntu24)"
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
  default     = 128

  validation {
    condition     = var.os_disk_size >= 100   && var.os_disk_size <= 16384
    error_message = "The os_disk_size value must be between 100 and 16384."
  }
}

variable "run_as_user" {
  description = "User account used to run ArcGIS Notebook Server"
  type        = string
  default     = "arcgis"
}

variable "skip_create_image" {
  description = "If true, Packer will not create the VM image. Useful for setting to true during a build test stage."
  type = bool
  default = false
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
