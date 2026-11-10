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
  description = "ArcGIS Enterprise deployment ID"
  type        = string
  default     = "enterprise-base-linux"

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

variable "ingress_id" {
  description = "ArcGIS Enterprise ingress ID"
  type        = string
  default     = "enterprise-ingress"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.ingress_id))
    error_message = "The ingress_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m7i.2xlarge"
}

variable "is_ha" {
  description = "If true, the deployment is in high availability mode"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
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

variable "os_disk_size" {
  description = "OS disk size in GiB for all deployment EC2 instances"
  type        = number
  default     = 256

  validation {
    condition     = var.os_disk_size >= 256 && var.os_disk_size <= 16384 && floor(var.os_disk_size) == var.os_disk_size
    error_message = "The os_disk_size value must be an integer between 256 and 16384."
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

variable "os_disk_type" {
  description = "OS disk type (gp3)"
  type        = string
  default     = "gp3"
  validation {
    condition     = var.os_disk_type == "gp3"
    error_message = "OS disks must use gp3."
  }
}

variable "data_disk_size" {
  description = "Primary and standby persistent data disk capacity in GiB; cannot be smaller than the image"
  type        = number
  default     = 1024
  validation {
    condition     = var.data_disk_size >= 1 && var.data_disk_size <= 16384 && floor(var.data_disk_size) == var.data_disk_size
    error_message = "Data disk size must be an integer between 1 and 16384 GiB."
  }
}

variable "data_disk_type" {
  description = "Primary and standby data EBS disk type"
  type        = string
  default     = "gp3"
  validation {
    condition     = contains(["gp3", "io1", "io2"], var.data_disk_type)
    error_message = "Data disks must use gp3, io1, or io2."
  }
}

variable "data_disk_iops" {
  description = "Provisioned data disk IOPS"
  type        = number
  default     = 3000
  validation {
    condition = floor(var.data_disk_iops) == var.data_disk_iops && (
      var.data_disk_type == "gp3" ? var.data_disk_iops >= 3000 && var.data_disk_iops <= 16000 && var.data_disk_iops <= var.data_disk_size * 500 :
      var.data_disk_iops >= 100 && var.data_disk_iops <= 64000 && var.data_disk_iops <= var.data_disk_size * (var.data_disk_type == "io1" ? 50 : 1000)
    )
    error_message = "Data IOPS must satisfy the selected EBS disk type and capacity limits."
  }
}

variable "data_disk_throughput" {
  description = "Data disk throughput in MiB/s (gp3 only; ignored for io1/io2)"
  type        = number
  default     = 125
  validation {
    condition     = var.data_disk_type != "gp3" || (var.data_disk_throughput >= 125 && var.data_disk_throughput <= 1000 && var.data_disk_throughput <= var.data_disk_iops * 0.25)
    error_message = "gp3 throughput must be 125-1000 MiB/s and at most one quarter of data IOPS."
  }
}

variable "subnet_ids" {
  description = "EC2 instances subnet IDs (by default, the first two private VPC subnets are used)"
  type        = list(string)
  default     = []
}