# Copyright 2024-2026 Esri
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

variable "container_registry_password" {
  description = "Source container registry user password"
  type        = string
  sensitive   = true
  default     = null
}

variable "container_registry_url" {
  description = "Source container registry URL"
  type        = string
  default     = "docker.io"
}

variable "container_registry_user" {
  description = "Source container registry user name"
  type        = string
  default     = null
}

variable "default_node_pool" {
  description = <<EOT
  <p>Default AKS node pool configuration properties:</p>
  <ul>
  <li>name - The name which should be used for the default Kubernetes Node Pool</li>
  <li>vm_size - The size of the Virtual Machine</li>
  <li>os_disk_size_gb - The size of the OS Disk which should be used for each agent in the Node Pool</li>
  <li>node_count - The initial number of nodes which should exist in this Node Pool</li>
  <li>max_count - The maximum number of nodes which should exist in this Node Pool</li>
  <li>min_count - The minimum number of nodes which should exist in this Node Pool</li>
  </ul>
  EOT  
  type = object({
    name            = string
    vm_size         = string
    os_disk_size_gb = number
    node_count      = number
    max_count       = number
    min_count       = number
  })
  default = {
    name            = "default"
    vm_size         = "Standard_D8s_v5"
    os_disk_size_gb = 1024
    node_count      = 4
    max_count       = 8
    min_count       = 4
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

variable "kubernetes_version" {
  description = "AKS Kubernetes version"
  type        = string
  default     = "1.33.5"
}

variable "subnet_id" {
  description = "AKS cluster subnet ID"
  type        = string
  default     = null
}
