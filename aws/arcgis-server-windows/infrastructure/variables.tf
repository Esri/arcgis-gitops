# Copyright 2024 Esri
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
 
variable "os" {
  description = "Operating system id (windows2022)"
  type        = string
  default     = "windows2022"

  validation {
    condition     = contains(["windows2022"], var.os)
    error_message = "Valid value for os variable is windows2022."
  }
}

variable "site_id" {
  description = "ArcGIS site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "deployment_id" {
  description = "ArcGIS Server deployment Id"
  type        = string
  default     = "arcgis-server"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }  
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

variable "subnet_ids" {
  description = "EC2 instances subnet IDs (by default, the first two private VPC subnets are used)"
  type        = list(string)
  default     = []
}

variable "internal_load_balancer" {
  description = "If true, the load balancer scheme is set to 'internal'"
  type        = bool
  default     = false
}

variable "ssl_certificate_arn" {
  description = "SSL certificate ARN for HTTPS listener of the load balancer"
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

variable "deployment_fqdn" {
  description = "Fully qualified domain name of the ArcGIS Server deployment"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn)) || var.deployment_fqdn == null
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "hosted_zone_id" {
  description = "The Route 53 hosted zone ID for the deployment FQDN"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^Z[0-9A-Z]{14,}$", var.hosted_zone_id)) || var.hosted_zone_id == null
    error_message = "The hosted_zone_id value must be a valid Route 53 hosted zone ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6i.2xlarge"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB of primary and standby EC2 instances"
  type        = number
  default     = 1024
  
  validation {
    condition     = var.root_volume_size >= 100   && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 100 and 16384."
  }    
}

variable "fileserver_instance_type" {
  description = "EC2 instance type of fileserver"
  type        = string
  default     = "m6i.xlarge"
}

variable "fileserver_volume_size" {
  description = "Root EBS volume size in GB of fileserver EC2 instance"
  type        = number
  default     = 100

  validation {
    condition     = var.fileserver_volume_size >= 100   && var.fileserver_volume_size <= 16384
    error_message = "The fileserver_volume_size value must be between 100 and 16384."
  }    
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "node_count" {
  description = "Number of node EC2 instances"
  type        = number
  default     = 1
}

variable "web_context" {
  description = "Services web context"
  type        = string
  default     = "arcgis"
}

variable "instance_https_port" {
  description = "ArcGIS Server instance HTTPS port"
  type        = number
  default     = 6443

  validation {
    condition     = contains([443, 6443], var.instance_https_port)
    error_message = "Valid values for instance_https_port variable are 443 and 6443."
  }
}
