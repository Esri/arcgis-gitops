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
  default     = "enterprise-base-windows"

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

variable "root_volume_iops" {
  description = "Root EBS volume IOPS of primary and standby EC2 instances"
  type        = number
  default     = 3000

  validation {
    condition     = var.root_volume_iops >= 3000 && var.root_volume_iops <= 16000
    error_message = "The root_volume_iops value must be between 3000 and 16000."
  }
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB of primary and standby EC2 instances"
  type        = number
  default     = 1024

  validation {
    condition     = var.root_volume_size >= 256 && var.root_volume_size <= 16384
    error_message = "The root_volume_size value must be between 256 and 16384."
  }
}

variable "root_volume_throughput" {
  description = "Root EBS volume throughput in MB/s of primary and standby EC2 instances"
  type        = number
  default     = 125

  validation {
    condition     = var.root_volume_throughput >= 125 && var.root_volume_throughput <= 1000
    error_message = "The root_volume_throughput value must be between 125 and 1000."
  }
}

variable "fileserver_instance_type" {
  description = "EC2 instance type for the dedicated Windows file-server VM"
  type        = string
  default     = "m7i.xlarge"
}

variable "fileserver_data_volume_size" {
  description = "Data EBS volume size in GB for the dedicated file-server VM"
  type        = number
  default     = 2048

  validation {
    condition = (
      var.fileserver_data_volume_type == "gp3" ? var.fileserver_data_volume_size >= 1 && var.fileserver_data_volume_size <= 16384 :
      var.fileserver_data_volume_type == "io1" ? var.fileserver_data_volume_size >= 4 && var.fileserver_data_volume_size <= 16384 :
      var.fileserver_data_volume_type == "io2" ? var.fileserver_data_volume_size >= 4 && var.fileserver_data_volume_size <= 65536 :
      contains(["sc1", "st1"], var.fileserver_data_volume_type) ? var.fileserver_data_volume_size >= 125 && var.fileserver_data_volume_size <= 16384 :
      true
    )
    error_message = "The fileserver_data_volume_size value must be 1-16384 GiB for gp3, 4-16384 GiB for io1, 4-65536 GiB for io2, or 125-16384 GiB for sc1 and st1."
  }
}

variable "fileserver_data_volume_type" {
  description = "Data EBS volume type for the dedicated file-server VM"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "io1", "io2", "sc1", "st1"], var.fileserver_data_volume_type)
    error_message = "Valid values for fileserver_data_volume_type are gp3, io1, io2, sc1, and st1."
  }
}

variable "fileserver_data_volume_iops" {
  description = "Data EBS IOPS for the dedicated file-server VM when using provisioned IOPS volume types"
  type        = number
  default     = 5000

  validation {
    condition = (
      var.fileserver_data_volume_type == "gp3" ? var.fileserver_data_volume_iops >= 3000 && var.fileserver_data_volume_iops <= 80000 && var.fileserver_data_volume_iops <= var.fileserver_data_volume_size * 500 :
      var.fileserver_data_volume_type == "io1" ? var.fileserver_data_volume_iops >= 100 && var.fileserver_data_volume_iops <= 64000 && var.fileserver_data_volume_iops <= var.fileserver_data_volume_size * 50 :
      var.fileserver_data_volume_type == "io2" ? var.fileserver_data_volume_iops >= 100 && var.fileserver_data_volume_iops <= 256000 && var.fileserver_data_volume_iops <= var.fileserver_data_volume_size * 1000 :
      true
    )
    error_message = "The fileserver_data_volume_iops value must be 3000-80000 and at most 500 IOPS/GiB for gp3, 100-64000 and at most 50 IOPS/GiB for io1, or 100-256000 and at most 1000 IOPS/GiB for io2. IOPS is not sent for sc1 or st1."
  }
}

variable "fileserver_data_volume_throughput" {
  description = "Data EBS throughput in MB/s for the dedicated file-server VM"
  type        = number
  default     = 250

  validation {
    condition = var.fileserver_data_volume_type != "gp3" || (
      var.fileserver_data_volume_throughput >= 125 &&
      var.fileserver_data_volume_throughput <= 2000 &&
      var.fileserver_data_volume_throughput <= var.fileserver_data_volume_iops * 0.25
    )
    error_message = "For gp3, fileserver_data_volume_throughput must be 125-2000 MiB/s and no more than 0.25 times fileserver_data_volume_iops. Throughput is not sent for io1, io2, sc1, or st1."
  }
}

variable "subnet_ids" {
  description = "EC2 instances subnet IDs (by default, the first two private VPC subnets are used)"
  type        = list(string)
  default     = []
}
