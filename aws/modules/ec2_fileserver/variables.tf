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

variable "enterprise_id" {
  description = "ArcGIS Enterprise ID"
  type        = string
}

variable "deployment_id" {
  description = "ArcGIS deployment ID"
  type        = string
}

variable "fileserver_deployment_id" {
  description = "Use the Windows file server from the deployment with the given ID. If not specified, a dedicated file-server VM is created for this deployment."
  type        = string
  default     = null

  validation {
    condition     = var.fileserver_deployment_id == null || can(regex("^[a-z0-9-]{3,25}$", var.fileserver_deployment_id))
    error_message = "The fileserver_deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the file-server VM"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID shared with the primary deployment VM"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "referenced_security_group_id" {
  description = "Deployment security group allowed to access SMB services"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 private hosted zone ID"
  type        = string
}

variable "arcgis_template_id" {
  description = "ArcGIS template tag value"
  type        = string
}

variable "arcgis_version" {
  description = "ArcGIS version tag value"
  type        = string
  default     = null
}

variable "data_volume_size" {
  description = "Data EBS volume size in GB"
  type        = number

  validation {
    condition = (
      var.data_volume_type == "gp3" ? var.data_volume_size >= 1 && var.data_volume_size <= 16384 :
      var.data_volume_type == "io1" ? var.data_volume_size >= 4 && var.data_volume_size <= 16384 :
      var.data_volume_type == "io2" ? var.data_volume_size >= 4 && var.data_volume_size <= 65536 :
      contains(["sc1", "st1"], var.data_volume_type) ? var.data_volume_size >= 125 && var.data_volume_size <= 16384 :
      true
    )
    error_message = "The data_volume_size value must be 1-16384 GiB for gp3, 4-16384 GiB for io1, 4-65536 GiB for io2, or 125-16384 GiB for sc1 and st1."
  }

}

variable "os_disk_size" {
  description = "File-server OS disk capacity in GiB"
  type        = number
  default     = 256
  validation {
    condition     = var.os_disk_size >= 256 && var.os_disk_size <= 16384 && floor(var.os_disk_size) == var.os_disk_size
    error_message = "OS disk capacity must be an integer between 256 and 16384 GiB."
  }
}

variable "os_disk_type" {
  description = "File-server OS disk type (gp3)"
  type        = string
  default     = "gp3"
  validation {
    condition     = var.os_disk_type == "gp3"
    error_message = "OS disks must use gp3."
  }
}

variable "os_disk_iops" {
  description = "File-server OS disk IOPS"
  type        = number
  default     = 3000
  validation {
    condition     = var.os_disk_iops >= 3000 && var.os_disk_iops <= 16000
    error_message = "OS IOPS must be between 3000 and 16000."
  }
}

variable "os_disk_throughput" {
  description = "File-server OS disk throughput in MiB/s"
  type        = number
  default     = 125
  validation {
    condition     = var.os_disk_throughput >= 125 && var.os_disk_throughput <= 1000 && var.os_disk_throughput <= var.os_disk_iops * 0.25
    error_message = "OS throughput must be 125-1000 MiB/s and at most one quarter of OS IOPS."
  }
}
variable "data_volume_type" {
  description = "Data EBS volume type"
  type        = string

  validation {
    condition     = contains(["gp3", "io1", "io2", "sc1", "st1"], var.data_volume_type)
    error_message = "Valid values for data_volume_type are gp3, io1, io2, sc1, and st1."
  }
}

variable "data_volume_iops" {
  description = "Data EBS volume IOPS"
  type        = number

  validation {
    condition = (
      var.data_volume_type == "gp3" ? var.data_volume_iops >= 3000 && var.data_volume_iops <= 80000 && var.data_volume_iops <= var.data_volume_size * 500 :
      var.data_volume_type == "io1" ? var.data_volume_iops >= 100 && var.data_volume_iops <= 64000 && var.data_volume_iops <= var.data_volume_size * 50 :
      var.data_volume_type == "io2" ? var.data_volume_iops >= 100 && var.data_volume_iops <= 256000 && var.data_volume_iops <= var.data_volume_size * 1000 :
      true
    )
    error_message = "The data_volume_iops value must be 3000-80000 and at most 500 IOPS/GiB for gp3, 100-64000 and at most 50 IOPS/GiB for io1, or 100-256000 and at most 1000 IOPS/GiB for io2. IOPS is not sent for sc1 or st1."
  }
}

variable "data_volume_throughput" {
  description = "Data EBS volume throughput in MB/s"
  type        = number

  validation {
    condition = var.data_volume_type != "gp3" || (
      var.data_volume_throughput >= 125 &&
      var.data_volume_throughput <= 2000 &&
      var.data_volume_throughput <= var.data_volume_iops * 0.25
    )
    error_message = "For gp3, data_volume_throughput must be 125-2000 MiB/s and no more than 0.25 times data_volume_iops. Throughput is not sent for io1, io2, sc1, or st1."
  }
}