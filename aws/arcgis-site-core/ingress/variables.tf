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

variable "aws_region" {
  description = "AWS region Id"
  type        = string
}

variable "client_cidr_blocks" {
  description = "Client CIDR blocks"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for b in var.client_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in vpc_cidr_block list must be in IPv4 CIDR block format."
  }
}

variable "deployment_fqdn" {
  description = "Fully qualified domain name of the deployment"
  type        = string
  
  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn))
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "enable_access_log" {
  description = "Enable access logging for the load balancer"
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "The Route 53 public hosted zone ID for the domain"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^Z[0-9A-Z]{12,}$", var.hosted_zone_id)) || var.hosted_zone_id == null
    error_message = "The hosted_zone_id value must be a valid Route 53 hosted zone ID."
  }
}

variable "http_ports" {
  description = "List of HTTP ports for the load balancer"
  type        = list(number)
  default     = [80]
}

variable "https_ports" {
  description = "List of HTTPS ports for the load balancer"
  type        = list(number)
  default     = [443, 6443, 7443, 11443]
}

variable "internal_load_balancer" {
  description = "If true, the load balancer scheme is set to 'internal'"
  type        = bool
  default     = false
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

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for HTTPS listeners of the load balancer"
  type        = string

  validation {
    condition     = can(regex("^arn:.+:acm:.+:\\d+:certificate\\/.+$", var.ssl_certificate_arn))
    error_message = "The ssl_certificate_arn value must be an ACM certificate ARN."
  }
}

variable "ssl_policy" {
  description = "Security Policy that should be assigned to the ALB to control the SSL protocol and ciphers"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
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