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

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "hosted_zone_name" {
  description = "Private hosted zone name"
  type        = string
  default     = "arcgis-enterprise.internal"

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.hosted_zone_name))
    error_message = "The hosted_zone_name value must be a valid domain name."
  }
}

variable "availability_zones" {
  description = "AWS availability zones (if the list contains less that two elements, the first two available availability zones in the AWS region will be used.)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.vpc_cidr_block))
    error_message = "The vpc_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "public_subnets_cidr_blocks" {
  description = "CIDR blocks of public subnets"
  type        = list(string)
  default = [
    "10.0.0.0/24",
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  validation {
    condition = alltrue([
      for b in var.public_subnets_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in public_subnets_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "private_subnets_cidr_blocks" {
  description = "CIDR blocks of private subnets"
  type        = list(string)
  default = [
    "10.0.64.0/24",
    "10.0.65.0/24",
    "10.0.66.0/24"
  ]

  validation {
    condition = alltrue([
      for b in var.private_subnets_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in private_subnets_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "isolated_subnets_cidr_blocks" {
  description = "CIDR blocks of isolated subnets"
  type        = list(string)
  default = [
    "10.0.128.0/24",
    "10.0.129.0/24",
    "10.0.130.0/24"
  ]

  validation {
    condition = alltrue([
      for b in var.isolated_subnets_cidr_blocks : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", b))
    ])
    error_message = "All elements in isolated_subnets_cidr_blocks list must be in IPv4 CIDR block format."
  }
}

variable "gateway_vpc_endpoints" {
  description = "List of gateway VPC endpoints to create"
  type        = list(string)
  default = [
    "dynamodb",
    "s3"
  ]
}

variable "interface_vpc_endpoints" {
  description = "List of interface VPC endpoints to create"
  type        = list(string)
  default = [
    "ec2",
    "ec2messages",
    "ecr.api",
    "ecr.dkr",
    "elasticloadbalancing",
    "logs",
    "monitoring",
    "ssm",
    "ssmmessages",
    "sts"
  ]
}

variable "images" {
  description = "AMI search filters by operating  system"
  type        = map(any)
  default = {
    windows2022 = {
      ami_name_filter = "Windows_Server-2022-English-Full-Base-*",
      owner           = "amazon",
      description     = "Microsoft Windows Server 2022 Full Locale English AMI"
    }
    ubuntu20 = {
      ami_name_filter : "ubuntu/images/hvm-ssd/ubuntu-*20*-amd64-server-*",
      owner : "099720109477", # Canonical
      description : "Canonical, Ubuntu, 20.04 LTS, amd64 focal image"
    }
    ubuntu22 = {
      ami_name_filter : "ubuntu/images/hvm-ssd/ubuntu-*22*-amd64-server-*",
      owner : "099720109477", # Canonical
      description : "Canonical, Ubuntu, 22.04 LTS, amd64 focal image"
    }
    rhel8 = {
      ami_name_filter : "RHEL-8.9.0_HVM-*-x86_64-*-Hourly2-GP3",
      owner : "309956199498", # Red Hat
      description : "Red Hat Enterprise Linux version 8 (HVM), EBS General Purpose (SSD) Volume Type"
    }
    rhel9 = {
      ami_name_filter : "RHEL-9.3.0_HVM-*-x86_64-*-Hourly2-GP3",
      owner : "309956199498", # Red Hat
      description : "Red Hat Enterprise Linux version 9 (HVM), EBS General Purpose (SSD) Volume Type"
    }
    sles15 = {
      ami_name_filter : "suse-sles-15-*-v*-hvm-ssd-x86_64",
      owner : "013907871322", # Amazon
      description : "SUSE Linux Enterprise Server 15 (HVM, 64-bit, SSD-Backed)"
    }
  }
}
