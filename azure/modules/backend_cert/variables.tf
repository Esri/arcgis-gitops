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

variable "common_name" {
  description = "Common Name (CN) to use in the certificate."
  type        = string
}

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment ID"
  type        = string
}

variable "dns_names" {
  description = "List of DNS names to include as SANs in the certificate."
  type = list(string)
  default = []
}

variable "ingress_id" {
  description = "ingress ID."
  type        = string
  default     = "enterprise-ingress"
}

variable "ip_addresses" {
  description = "List of IP addresses to include as SANs in the certificate."
  type        = list(string)
  default     = []
}

variable "key_vault_id" {
  description = "ID of the Key Vault where the trusted root certificate is stored."
  type        = string
}

variable "pfx_password" {
  description = "Password for the generated PFX file."
  type        = string
  sensitive   = true
}

variable "storage_account_name" {
  description = "Name of the storage account where the backend certificate will be stored."
  type        = string
}

variable "storage_container_name" {
  description = "Name of the storage container where the backend certificate will be stored."
  type        = string
}

variable "validity_period_hours" {
  description = "Number of hours the generated backend certificate will be valid for."
  type        = number
  default     = 87600 # 10 years
}