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

variable "settings" {
  description = "Base-enterprise VM settings; the data disk is restored from image LUN 0"
  type = object({
    name              = string
    resource_group_id = string
    location          = string
    size              = string
    image_id          = string
    nic_id            = string
    identity_id       = string
    scale_set_id      = string
    os_disk_size      = number
    data_disk_size    = number
    windows           = bool
    admin_username    = string
    public_key        = optional(string)
    tags              = map(string)
  })
}

variable "admin_password" {
  description = "VM administrator password; omit for SSH-key authentication"
  type        = string
  sensitive   = true
  default     = null
}