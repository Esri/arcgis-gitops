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

variable "enterprise_id" {
  description = "ArcGIS Enterprise ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.enterprise_id))
    error_message = "The enterprise_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "fileserver_deployment_id" {
  description = "Use the EFS filesystem from the deployment with the given ID. If not specified, a dedicated EFS filesystem will be created for this deployment."
  type        = string
  default     = null

  validation {
    condition     = var.fileserver_deployment_id == null || can(regex("^[a-z0-9-]{3,25}$", var.fileserver_deployment_id))
    error_message = "The fileserver_deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
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

variable "key_vault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region where the file server resources will be created or are located (if fileserver_deployment_id is specified)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the file server resources will be created or are located (if fileserver_deployment_id is specified)."
  type        = string
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
  description = "EFS target subnet ID."
  type        = string
}

variable "unique_name_suffix" {
  description = "A unique suffix to append to the names of created resources to avoid naming conflicts."
  type        = string
}