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

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "enterprise_id" {
  description = "ArcGIS Enterprise ID"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.enterprise_id))
    error_message = "The enterprise_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "machine_roles" {
  description = "Deployment Windows VM roles whose C: partitions will be prepared"
  type        = list(string)

  validation {
    condition     = length(var.machine_roles) > 0 && alltrue([for role in var.machine_roles : contains(["primary", "standby", "fileserver"], role)])
    error_message = "Specify at least one of primary, standby, or fileserver."
  }
}

variable "os_disk_size" {
  description = "Expected minimum guest OS disk capacity in GiB, matching the provisioned managed disk"
  type        = number

  validation {
    condition     = var.os_disk_size >= 256 && var.os_disk_size <= 4095 && floor(var.os_disk_size) == var.os_disk_size
    error_message = "The os_disk_size value must be an integer between 256 and 4095 GiB."
  }
}
