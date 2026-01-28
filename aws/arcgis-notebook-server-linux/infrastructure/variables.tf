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
 
variable "aws_region" {
  description = "AWS region Id"
  type        = string
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "backup_retention" {
  description = "Number of days to retain backups"
  type        = number
  default     = 14
}

variable "deployment_id" {
  description = "ArcGIS Notebook Server deployment Id"
  type        = string
  default     = "notebook-server-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "ingress_deployment_id" {
  description = "Ingress deployment Id"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.ingress_deployment_id))
    error_message = "The ingress_deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m7i.2xlarge"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "node_count" {
  description = "Number of node EC2 instances"
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 0
    error_message = "The node_count value must be greater than or equal to 0."
  }
}

variable "notebook_server_web_context" {
  description = "ArcGIS Notebook Server web context"
  type        = string
  default     = "notebooks"
}

variable "portal_deployment_id" {
  description = "Portal for ArcGIS deployment Id"
  type        = string
  default     = "enterprise-base-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.portal_deployment_id))
    error_message = "The portal_deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "root_volume_iops" {
  description = "Root EBS volume IOPS of primary and standby EC2 instances"
  type        = number
  default     = 16000

  validation {
    condition     = var.root_volume_iops >= 3000   && var.root_volume_iops <= 16000
    error_message = "The root_volume_iops value must be between 3000 and 16000."
  }    
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 1024

  validation {
    condition     = var.root_volume_size >= 100 && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 100 and 16384."
  }
}

variable "root_volume_throughput" {
  description = "Root EBS volume throughput in MB/s of primary and standby EC2 instances"
  type        = number
  default     = 1000

  validation {
    condition     = var.root_volume_throughput >= 125 && var.root_volume_throughput <= 1000
    error_message = "The root_volume_throughput value must be between 125 and 1000."
  }
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

variable "subnet_ids" {
  description = "EC2 instances subnet IDs (by default, the first two private VPC subnets are used)"
  type        = list(string)
  default     = []
}
