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
  description = "Use the NFS file share from the deployment with the given ID. If not specified, a dedicated NFS file share will be created for this deployment."
  type        = string
  default     = null

  validation {
    condition     = var.fileserver_deployment_id == null || can(regex("^[a-z0-9-]{3,25}$", var.fileserver_deployment_id))
    error_message = "The fileserver_deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "fileserver_size" {
  description = "Provisioned NFS file share capacity in GiB"
  type        = number
  default     = 1024

  validation {
    condition     = var.fileserver_size == floor(var.fileserver_size) && var.fileserver_size >= (var.fileserver_billing_model_version == "V2" ? 32 : 1) && var.fileserver_size <= 5120
    error_message = "The fileserver_size value must be an integer between 1 and 5120 GiB (at least 32 GiB for V2)."
  }
}

variable "fileserver_billing_model_version" {
  description = "Azure Files provisioning model: V1 for existing shares, V2 for independent IOPS and throughput on new shares. Changing this replaces the storage account."
  type        = string
  default     = "V1"
  nullable    = false

  validation {
    condition     = contains(["V1", "V2"], var.fileserver_billing_model_version)
    error_message = "The fileserver_billing_model_version value must be V1 or V2."
  }
}

variable "fileserver_iops" {
  description = "Provisioned IOPS for a dedicated V2 share. Required for V2; must be null for V1 or an existing shared file server."
  type        = number
  default     = null

  validation {
    condition = var.fileserver_deployment_id != null || var.fileserver_billing_model_version != "V2" ? var.fileserver_iops == null : (
      var.fileserver_iops == null ? false : var.fileserver_iops == floor(var.fileserver_iops) && var.fileserver_iops >= 3000 && var.fileserver_iops <= min(102400, 5 * (3000 + var.fileserver_size))
    )
    error_message = "Dedicated V2 shares require integer fileserver_iops from 3000 to min(102400, 5 * (3000 + fileserver_size)); other shares require null."
  }
}

variable "fileserver_throughput" {
  description = "Provisioned throughput in MiB/s for a dedicated V2 share. Required for V2; must be null for V1 or an existing shared file server."
  type        = number
  default     = null

  validation {
    condition = var.fileserver_deployment_id != null || var.fileserver_billing_model_version != "V2" ? var.fileserver_throughput == null : (
      var.fileserver_throughput == null ? false : var.fileserver_throughput == floor(var.fileserver_throughput) && var.fileserver_throughput >= 100 && var.fileserver_throughput <= min(10340, 5 * (100 + ceil(0.1 * var.fileserver_size)))
    )
    error_message = "Dedicated V2 shares require integer fileserver_throughput from 100 to min(10340, 5 * (100 + ceil(0.1 * fileserver_size))); other shares require null."
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
  description = "NFS file share subnet ID."
  type        = string
}

variable "unique_name_suffix" {
  description = "A unique suffix to append to the names of created resources to avoid naming conflicts."
  type        = string
}