# Copyright 2024-2025 Esri
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

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "resource_group_name" {
  description = "AKS cluster resource group name"  
  type = string
}

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.site_id))
    error_message = "The site_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "grafana_major_version" {
  description = "Major version of Grafana to deploy"
  type        = number
  default     = 11
}