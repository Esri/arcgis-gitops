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
    error_message = "Enterprise ID must contain 3-6 lowercase letters, digits, or hyphens."
  }
}

variable "deployment_id" {
  description = "ArcGIS deployment ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "Deployment ID must contain 3-25 lowercase letters, digits, or hyphens."
  }
}

variable "machine_role" {
  description = "Owned Windows machine role to prepare"
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]{0,255}$", var.machine_role))
    error_message = "Machine role must be a literal tag value using letters, digits, dots, underscores, or hyphens, starting with a letter or digit."
  }
}

variable "image_role" {
  description = "Image identity kind expected on the target disks, independent of the machine role tag"
  type        = string
  default     = "application"
  validation {
    condition     = contains(["application", "fileserver"], var.image_role)
    error_message = "Image role must be application or fileserver."
  }
}

variable "os_disk_size" {
  description = "Expected guest-visible OS EBS capacity in GiB"
  type        = number
  validation {
    condition     = var.os_disk_size >= 256 && var.os_disk_size <= 16384 && floor(var.os_disk_size) == var.os_disk_size
    error_message = "OS disk capacity must be an integer between 256 and 16384 GiB."
  }
}

variable "data_disk_size" {
  description = "Expected guest-visible data EBS capacity in GiB"
  type        = number
  validation {
    condition     = var.data_disk_size >= 1 && var.data_disk_size <= 65536 && floor(var.data_disk_size) == var.data_disk_size
    error_message = "Data disk capacity must be an integer between 1 and 65536 GiB."
  }
}

variable "expected_account" {
  description = "When set, verify completed disk preparation and match the configured account without changing the disks."
  type        = string
  default     = null
}

variable "expected_snapshot_id" {
  description = "Expected AMI /dev/sdf snapshot ID for infrastructure disk preparation."
  type        = string
  default     = null
}

variable "allow_data_disk_rebind" {
  description = "Explicitly allow an application data disk binding to be replaced during an approved AWS Backup recovery."
  type        = bool
  default     = false
}

variable "log_to_apply" {
  description = "Replay S3 command output during Terraform apply."
  type        = bool
  default     = false
}

variable "fileserver_private_dns" {
  description = "Private DNS alias to configure on the owned file server during observable preparation."
  type        = string
  default     = null
}

variable "fileserver_registry_script" {
  description = "Module-local registry setup script supplied by the file-server module."
  type        = string
  default     = ""
}
