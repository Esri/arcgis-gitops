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
    condition     = contains(["primary", "standby", "fileserver"], var.machine_role)
    error_message = "Machine role must be primary, standby, or fileserver."
  }
}

variable "instance_id" {
  description = "Exact EC2 instance ID targeted by SSM"
  type        = string
  validation {
    condition     = can(regex("^i-[0-9a-f]+$", var.instance_id))
    error_message = "A valid EC2 instance ID is required."
  }
}

variable "data_volume_id" {
  description = "Actual EBS volume ID restored from the AMI /dev/sdf mapping"
  type        = string
  validation {
    condition     = can(regex("^vol-[0-9a-f]+$", var.data_volume_id))
    error_message = "A valid data EBS volume ID is required."
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
