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

variable "azure_region" {
  description = "Azure region display name"
  type        = string
}

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment Id"
  type        = string
  default     = "enterprise-base-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "fileserver_size" {
  description = "Maximum size of the NFS file share in GB"
  type        = number
  default     = 1024

  validation {
    condition     = var.fileserver_size >= 1 && var.fileserver_size <= 5120
    error_message = "The fileserver_size value must be between 1 and 5120."
  }
}

variable "ingress_deployment_id" {
  description = "ArcGIS Enterprise ingress deployment Id"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.ingress_deployment_id))
    error_message = "The ingress_deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "is_ha" {
  description = "If true, the deployment is in high availability mode"
  type        = bool
  default     = true
}

variable "os_disk_size" {
  description = "OS disk size in GB"
  type        = number
  default     = 256

  validation {
    condition     = var.os_disk_size >= 100 && var.os_disk_size <= 4095
    error_message = "The os_disk_size value must be between 100 and 4095."
  }
}

variable "portal_web_context" {
  description = "Portal for ArcGIS web context"
  type        = string
  default     = "portal"
}

variable "server_web_context" {
  description = "ArcGIS Server web context"
  type        = string
  default     = "server"
}

variable "site_id" {
  description = "ArcGIS site Id"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.site_id))
    error_message = "The site_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "storage_replication_type" {
  description = "The replication type of the storage accounts. Possible values are: LRS (Locally-redundant storage), ZRS (Zone-redundant storage)."
  type        = string
  default     = "ZRS"

  validation {
    condition     = var.storage_replication_type == "LRS" || var.storage_replication_type == "ZRS"
    error_message = "The storage_replication_type value must be one of the following: LRS, ZRS."
  }
}

variable "subnet_id" {
  description = "VMs subnet ID (by default, the first private subnet is used)"
  type        = string
  default     = null
}

variable "vm_admin_password" {
  description = "VM administrator password"
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = var.vm_admin_password != null || var.vm_admin_public_ssh_key_path != null
    error_message = "Either vm_admin_password or vm_admin_public_ssh_key_path variable must be provided."
  }
}

variable "vm_admin_public_ssh_key_path" {
  description = "VM administrator public SSH key file path. If not provided, password authentication will be used for the VMs."
  type        = string
  default     = null

  validation {
    condition     = var.vm_admin_public_ssh_key_path == null || try(fileexists(var.vm_admin_public_ssh_key_path), false)
    error_message = "The file specified in vm_admin_public_ssh_key_path does not exist."
  }
}

variable "vm_admin_username" {
  description = "VM administrator username"
  type        = string
  default     = "vmadmin"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_D8s_v5"
}
