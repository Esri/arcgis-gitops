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

variable "enabled_log_categories" {
  description = "List of log categories to enable for the Application Gateway"
  type        = list(string)
  default     = [
    "ApplicationGatewayAccessLog",
    "ApplicationGatewayFirewallLog",
    "ApplicationGatewayPerformanceLog"
  ]
}

variable "deployment_fqdn" {
  description = "Fully qualified domain name of the ArcGIS Enterprise site"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn))
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "deployment_id" {
  description = "ArcGIS Enterprise site ingress deployment Id"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
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

variable "ingress_private_ip" {
  description = "IP address of the Application Gateway private frontend configuration. The IP address must be in the Application Gateway subnet."
  type        = string
  default     = "10.5.255.254"

  validation {
    condition = var.ingress_private_ip == null || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.ingress_private_ip))
    error_message = "The ingress_private_ip value must be a valid IPv4 address."
  }
}

variable "log_retention" {
  description = "Retention period in days for logs"
  type        = number
  default     = 90
}

variable "request_timeout" {
  description = "Request timeout in seconds for the Application Gateway"
  type        = number
  default     = 60

  validation {
    condition     = var.request_timeout >= 60 && var.request_timeout <= 600
    error_message = "The request_timeout value must be between 60 and 600 seconds."
  }  
}

variable "site_id" {
  description = "ArcGIS site Id"
  type        = string
  default     = "arcgis"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.site_id))
    error_message = "The site_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "ssl_certificate_secret_id" {
  description = "Key Vault secret ID of SSL certificate for the Application Gateway HTTPS listeners"
  type        = string
}

variable "ssl_policy" {
  description = "Predefined SSL policy that should be assigned to the Application Gateway to control the SSL protocol and ciphers"
  type        = string
  default     = "AppGwSslPolicy20220101"
}

variable "subnet_id" {
  description = "Application Gateway subnet ID (by default, the second app gateway subnet is used)"
  type        = string
  default     = null
}

variable "zones" {
  description = "List of availability zones for the Application Gateway"
  type        = list(string)
  default     = ["1", "2"]
}

variable "routing_rules" {
  description = "List of routing rules for the Application Gateway"
  type        = list(any)
  default     = [{
    name     = "web-adaptor"
    frontend_port = 443
    backend_port  = 443
    protocol = "Https"
    priority = 10
    rules    = [{
      name   = "server"
      pool   = "enterprise-base"
      probe  = "/server/rest/info/healthcheck"
      paths  = ["/server/*"]
    }, {
      name   = "portal"
      pool   = "enterprise-base"
      probe  = "/portal/portaladmin/healthCheck"
      paths  = ["/portal/*"]
    }]
  }, {
    name     = "server"
    frontend_port = 6443
    backend_port  = 6443
    protocol = "Https"
    priority = 11
    rules    = [{
      name   = "arcgis-6443"
      pool   = "enterprise-base"
      probe  = "/arcgis/rest/info/healthcheck"
      paths  = ["/arcgis/*"]
    }]
  }, {
    name     = "portal"
    frontend_port = 7443
    backend_port  = 7443
    protocol = "Https"
    priority = 12
    rules    = [{
      name   = "arcgis-7443"
      pool   = "enterprise-base"
      probe  = "/arcgis/portaladmin/healthCheck"
      paths  = ["/arcgis/*"]
    }]
  }]
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