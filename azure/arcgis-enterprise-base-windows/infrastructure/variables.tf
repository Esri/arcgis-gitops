# Copyright 2025-2026 Esri
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
  description = "ArcGIS Enterprise deployment ID"
  type        = string
  default     = "enterprise-base-windows"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
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

variable "ingress_id" {
  description = "ArcGIS Enterprise ingress ID"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.ingress_id))
    error_message = "The ingress_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
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
  default     = 1024

  validation {
    condition     = var.os_disk_size >= 100 && var.os_disk_size <= 4095
    error_message = "The os_disk_size value must be between 100 and 4095."
  }
}

variable "fileserver_vm_size" {
  description = "Azure VM size for the dedicated Windows file-server VM"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "fileserver_backup_time" {
  description = "UTC start time for the daily file-server VM backup"
  type        = string
  default     = "23:00"

  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.fileserver_backup_time))
    error_message = "The fileserver_backup_time value must use 24-hour HH:MM format."
  }
}

variable "fileserver_backup_retention_days" {
  description = "Number of daily file-server VM recovery points to retain"
  type        = number
  default     = 30

  validation {
    condition     = var.fileserver_backup_retention_days >= 7 && var.fileserver_backup_retention_days <= 9999
    error_message = "The fileserver_backup_retention_days value must be between 7 and 9999."
  }
}

variable "fileserver_data_disk_size_gb" {
  description = "Data disk size in GB for the dedicated Windows file-server VM"
  type        = number
  default     = 2048

  validation {
    condition     = var.fileserver_data_disk_size_gb >= 128 && var.fileserver_data_disk_size_gb <= 65536
    error_message = "The fileserver_data_disk_size_gb value must be between 128 and 65536."
  }
}

variable "fileserver_data_disk_storage_account_type" {
  description = "Data disk storage account type for the dedicated Windows file-server VM"
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "PremiumV2_LRS", "UltraSSD_LRS"], var.fileserver_data_disk_storage_account_type)
    error_message = "Valid values for fileserver_data_disk_storage_account_type are Standard_LRS, StandardSSD_LRS, Premium_LRS, PremiumV2_LRS, and UltraSSD_LRS."
  }
}

variable "fileserver_data_disk_iops" {
  description = "Provisioned data disk IOPS for PremiumV2_LRS and UltraSSD_LRS disks"
  type        = number
  default     = null

  validation {
    condition = var.fileserver_data_disk_iops == null ? true : (
      var.fileserver_data_disk_storage_account_type == "PremiumV2_LRS"
      ? var.fileserver_data_disk_iops >= 3000 && var.fileserver_data_disk_iops <= 80000
      : var.fileserver_data_disk_storage_account_type == "UltraSSD_LRS" && var.fileserver_data_disk_iops >= 100 && var.fileserver_data_disk_iops <= 400000
    )
    error_message = "The fileserver_data_disk_iops value must be null, 3000-80000 for PremiumV2_LRS, or 100-400000 for UltraSSD_LRS."
  }
}

variable "fileserver_data_disk_throughput_mbps" {
  description = "Provisioned data disk throughput in MB/s for PremiumV2_LRS and UltraSSD_LRS disks"
  type        = number
  default     = null

  validation {
    condition = var.fileserver_data_disk_throughput_mbps == null ? true : (
      var.fileserver_data_disk_storage_account_type == "PremiumV2_LRS"
      ? var.fileserver_data_disk_throughput_mbps >= 125 && var.fileserver_data_disk_throughput_mbps <= 1200
      : var.fileserver_data_disk_storage_account_type == "UltraSSD_LRS" && var.fileserver_data_disk_throughput_mbps >= 1 && var.fileserver_data_disk_throughput_mbps <= 10000
    )
    error_message = "The fileserver_data_disk_throughput_mbps value must be null, 125-1200 for PremiumV2_LRS, or 1-10000 for UltraSSD_LRS."
  }
}

variable "storage_account_replication_type" {
  description = "Deployment storage account replication type"
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS"], var.storage_account_replication_type)
    error_message = "Valid values for storage_account_replication_type variable are LRS, GRS, RAGRS, and ZRS."
  }
}

variable "storage_account_tier" {
  description = "Deployment storage account tier"
  type        = string
  default     = "Premium"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Valid values for storage_account_tier variable are Standard and Premium."
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