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

variable "arcgis_enterprise_context" {
  description = "Context path to be used in the URL for ArcGIS Enterprise on Kubernetes"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9]{1,}$", var.arcgis_enterprise_context))
    error_message = "The arcgis_enterprise_context value must be an alphanumeric string."
  }
}

variable "azure_region" {
  description = "Azure region display name"
  type        = string
}

variable "enabled_log_categories" {
  description = "List of log categories to enable for the Application Gateway for Containers"
  type        = list(string)
  default     = [
    "TrafficControllerAccessLog",
    "TrafficControllerFirewallLog"
  ]
}

variable "deployment_id" {
  description = "ArcGIS Enterprise on Kubernetes deployment Id"
  type        = string
  default     = "enterprise-k8s"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "deployment_fqdn" {
  description = "Fully qualified domain name (FQDN) to access ArcGIS Enterprise on Kubernetes"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn))
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "dns_zone_name" {
  description = "The public DNS zone name for the domain"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.dns_zone_name)) || var.dns_zone_name == null
    error_message = "The dns_zone_name value must be a valid DNS zone name."
  }
}

variable "dns_zone_resource_group_name" {
  description = "The resource group name of the public DNS zone"
  type        = string
  default     = null

  validation {
    condition = can(regex("^[a-zA-Z0-9_\\-\\.()]{1,90}$", var.dns_zone_resource_group_name)) || var.dns_zone_resource_group_name == null
    error_message = "The dns_zone_resource_group_name value must be valid resource group name."
  }
}

variable "log_retention" {
  description = "Retention period in days for logs"
  type        = number
  default     = 90
}

variable "tls_certificate_path" {
  description = "File path to the TLS certificate for the HTTPS listener"
  type        = string
}

variable "tls_private_key_path" {
  description = "File path to the TLS certificate's private key for the HTTPS listener"
  type        = string
}

variable "ca_certificate_path" {
  description = "File path to the CA certificate used to validate the backend TLS certificate"
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

variable "waf_mode" {
  description = "Specifies the mode of the Web Application Firewall (WAF). Valid values are 'detect' and 'protect'."
  type        = string
  default     = "detect"
  validation {
    condition     = var.waf_mode == "detect" || var.waf_mode == "protect"
    error_message = "The waf_mode value must be either 'detect' or 'protect'."
  }
}
