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
}

variable "deployment_id" {
  description = "ArcGIS deployment ID"
  type        = string
}

variable "fileserver_deployment_id" {
  description = "Use the Windows file server from the deployment with the given ID. If not specified, a dedicated file-server VM is created for this deployment."
  type        = string
  default     = null

  validation {
    condition     = var.fileserver_deployment_id == null || can(regex("^[a-z0-9-]{3,25}$", var.fileserver_deployment_id))
    error_message = "The fileserver_deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "azure_region" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Deployment resource group name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID shared with the primary and standby VMs; the file server inherits this subnet's existing network security group"
  type        = string
}

variable "vault_id" {
  description = "Enterprise Key Vault ID"
  type        = string
}

variable "vm_identity_id" {
  description = "User-assigned managed identity ID"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size for the file-server VM"
  type        = string
}

variable "admin_username" {
  description = "VM administrator username"
  type        = string
}

variable "admin_password" {
  description = "VM administrator password"
  type        = string
  sensitive   = true
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB"
  type        = number
}

variable "data_disk_storage_account_type" {
  description = "Data disk storage account type"
  type        = string
}

variable "data_disk_iops" {
  description = "Provisioned data disk IOPS where supported"
  type        = number
  default     = null
}

variable "data_disk_throughput_mbps" {
  description = "Provisioned data disk throughput in MB/s where supported"
  type        = number
  default     = null
}