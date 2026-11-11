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

variable "arcgis_server_patches" {
  description = "File names of ArcGIS Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_version" {
  description = "ArcGIS Server version"
  type        = string
  default     = "12.1"

  validation {
    condition     = contains(["11.4", "11.5", "12.0", "12.1"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.4, 11.5, 12.0, and 12.1."
  }
}

variable "aws_region" {
  description = "AWS region ID"
  type        = string
  default     = env("AWS_DEFAULT_REGION")
}

variable "deployment_id" {
  description = "Deployment ID"
  type        = string
  default     = "server-linux-ansible"

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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m7i.2xlarge"
}

variable "os" {
  description = "Operating system ID (rhel9)"
  type        = string
  default     = "rhel9"

  validation {
    condition     = contains(["rhel9"], var.os)
    error_message = "Valid values for os variable are rhel9."
  }
}

variable "data_disk_size" {
  description = "Persistent /opt data EBS volume capacity baked into the image in GiB"
  type        = number
  default     = 256

  validation {
    condition     = var.data_disk_size >= 32 && var.data_disk_size <= 16384 && floor(var.data_disk_size) == var.data_disk_size
    error_message = "The data_disk_size value must be an integer between 32 and 16384 GiB for the image's 16000 IOPS gp3 volume."
  }
}

variable "os_disk_size" {
  description = "OS EBS disk size in GiB"
  type        = number
  default     = 256

  validation {
    condition     = var.os_disk_size >= 256 && var.os_disk_size <= 16384 && floor(var.os_disk_size) == var.os_disk_size
    error_message = "OS disk size must be an integer between 256 and 16384 GiB."
  }
}

variable "run_as_user" {
  description = "User account used to run ArcGIS Server"
  type        = string
  default     = "arcgis"
}

variable "server_web_context" {
  description = "ArcGIS Web Adaptor name"
  type        = string
  default     = "arcgis"
}

variable "skip_create_ami" {
  description = "If true, Packer will not create the AMI. Useful for setting to true during a build test stage."
  type        = bool
  default     = false
}

variable "use_webadaptor" {
  description = "If true, OpenJDK, Apache Tomcat, and ArcGIS Web Adaptor will be installed on the AMI."
  type        = bool
  default     = false
}