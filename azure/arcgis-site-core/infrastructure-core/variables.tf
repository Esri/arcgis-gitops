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

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.site_id))
    error_message = "The site_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "vnet_cidr_block" {
  description = "CIDR block for the site's virtual network"
  type        = string
  default     = "10.0.0.0/8"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.vnet_cidr_block))
    error_message = "The vnet_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "bastion_enabled" {
  description = "Enable Azure Bastion host"
  type        = bool
  default     = true
}

variable "bastion_source_cidr_blocks" {
  description = "CIDR blocks of bastion source traffic"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for b in var.bastion_source_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in bastion_source_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "bastion_subnet_cidr_block" {
  description = "CIDR block of bastion subnet"
  type        = string
  default     = "10.1.0.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.bastion_subnet_cidr_block))
    error_message = "The bastion_subnet_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "app_gateway_subnets_cidr_blocks" {
  description = "CIDR blocks of Application Gateway subnets"
  type        = list(string)
  default = [
    "10.4.0.0/16"
  ]

  validation {
    condition = alltrue([
      for b in var.app_gateway_subnets_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in app_gateway_subnets_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "private_subnets_cidr_blocks" {
  description = "CIDR blocks of private subnets"
  type        = list(string)
  default = [
    "10.3.0.0/16"
  ]

  validation {
    condition = alltrue([
      for b in var.private_subnets_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in private_subnets_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "internal_subnets_cidr_blocks" {
  description = "CIDR blocks of internal subnets"
  type        = list(string)
  default = [
    "10.2.0.0/16"
  ]

  validation {
    condition = alltrue([
      for b in var.internal_subnets_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in internal_subnets_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "service_endpoints" {
  description = "Service endpoints of internal subnets"
  type        = list(string)
  default     = []
}

