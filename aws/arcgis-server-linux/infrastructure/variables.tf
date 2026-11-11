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

variable "aws_region" {
  description = "AWS region ID"
  type        = string
}

variable "backup_retention" {
  description = "Number of days to retain backups"
  type        = number
  default     = 14
}

variable "backup_schedule" {
  description = "Backup schedule in cron format"
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "deployment_id" {
  description = "ArcGIS Server deployment ID"
  type        = string
  default     = "server-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
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

variable "fileserver_deployment_id" {
  description = "Use the EFS filesystem from the deployment with the given ID. If not specified, a dedicated EFS filesystem will be created for this deployment."
  type        = string
  default     = null

  validation {
    condition     = var.fileserver_deployment_id == null || can(regex("^[a-z0-9-]{3,25}$", var.fileserver_deployment_id))
    error_message = "The fileserver_deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "ingress_id" {
  description = "Ingress ID"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.ingress_id)) || var.ingress_id == null
    error_message = "The ingress_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
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

variable "listener_rule_priority" {
  description = "Priority of the ALB listener rule that forwards traffic to this deployment. The priority must be unique among all listener rules associated with the same ALB listener."
  type        = number
  default     = 110

  validation {
    condition     = var.listener_rule_priority >= 1 && var.listener_rule_priority <= 50000
    error_message = "The listener_rule_priority value must be between 1 and 50000."
  }
}

variable "node_count" {
  description = "Number of node EC2 instances (excluding the primary EC2 instance)"
  type        = number
  default     = 1
}

variable "portal_deployment_id" {
  description = "Portal for ArcGIS deployment ID"
  type        = string
  default     = null

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.portal_deployment_id)) || var.portal_deployment_id == null
    error_message = "The portal_deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "data_disk_size" {
  description = "Data EBS volume capacity in GiB; must be at least the AMI's /dev/sdf snapshot size"
  type        = number
  default     = 256

  validation {
    condition     = var.data_disk_size >= 1 && var.data_disk_size <= 16384 && floor(var.data_disk_size) == var.data_disk_size
    error_message = "The data_disk_size value must be an integer between 1 and 16384 GiB."
  }
}

variable "data_disk_iops" {
  description = "Data gp3 EBS volume IOPS on primary and node instances"
  type        = number
  default     = 3000

  validation {
    condition     = floor(var.data_disk_iops) == var.data_disk_iops && var.data_disk_iops >= 3000 && var.data_disk_iops <= 16000 && var.data_disk_iops <= max(3000, var.data_disk_size * 500)
    error_message = "Data disk IOPS must be an integer from 3000 to 16000 within the gp3 capacity limit."
  }
}

variable "data_disk_throughput" {
  description = "Data gp3 EBS volume throughput in MiB/s on primary and node instances"
  type        = number
  default     = 125

  validation {
    condition     = var.data_disk_throughput >= 125 && var.data_disk_throughput <= 1000 && var.data_disk_throughput <= var.data_disk_iops * 0.25
    error_message = "Data disk throughput must be between 125 and 1000 MiB/s and no more than one quarter of data_disk_iops."
  }
}

variable "os_disk_iops" {
  description = "OS gp3 disk IOPS for all deployment EC2 instances"
  type        = number
  default     = 3000

  validation {
    condition     = var.os_disk_iops >= 3000 && var.os_disk_iops <= 16000
    error_message = "The os_disk_iops value must be between 3000 and 16000."
  }
}

variable "os_disk_throughput" {
  description = "OS gp3 disk throughput in MiB/s for all deployment EC2 instances"
  type        = number
  default     = 125

  validation {
    condition     = var.os_disk_throughput >= 125 && var.os_disk_throughput <= 1000 && var.os_disk_throughput <= var.os_disk_iops * 0.25
    error_message = "OS throughput must be 125-1000 MiB/s and at most one quarter of OS IOPS."
  }
}

variable "os_disk_size" {
  description = "OS disk size in GiB for all deployment EC2 instances"
  type        = number
  default     = 256

  validation {
    condition     = var.os_disk_size >= 256 && var.os_disk_size <= 16384 && floor(var.os_disk_size) == var.os_disk_size
    error_message = "The os_disk_size value must be an integer between 256 and 16384."
  }
}

variable "subnet_ids" {
  description = "EC2 instances subnet IDs (by default, the first two private VPC subnets are used)"
  type        = list(string)
  default     = []
}
