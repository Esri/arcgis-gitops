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

variable "aws_region" {
  description = "AWS region Id"
  type        = string
}

variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}


variable "chef_client_paths" {
  description = "Chef/CINC Client setup S3 keys by operating system"
  type        = map(any)
  default = {
    windows2022 = {
      path        = "cinc/cinc-18.4.2-1-x64.msi"
      description = "Chef Client setup S3 key for Microsoft Windows Server 2022"
    }
    ubuntu20 = {
      path        = "cinc/cinc_18.4.2-1_amd64.deb"
      description = "Chef Client setup S3 key for Ubuntu 20.04 LTS"
    }
    ubuntu22 = {
      path        = "cinc/cinc_18.4.2-1_amd64.deb"
      description = "Chef Client setup S3 key for Ubuntu 22.04 LTS"
    }
    rhel8 = {
      path        = "cinc/cinc-18.4.2-1.el8.x86_64.rpm"
      description = "Chef Client setup S3 key for Red Hat Enterprise Linux version 8"
    }
    rhel9 = {
      path        = "cinc/cinc-18.4.2-1.el9.x86_64.rpm"
      description = "Chef Client setup S3 key for Red Hat Enterprise Linux version 9"
    }
    sles15 = {
      path        = "cinc/cinc-18.4.2-1.sles15.x86_64.rpm"
      description = "Chef Client setup S3 key for SUSE Linux Enterprise Server 15"
    }
  }
}

variable "arcgis_cookbooks_path" {
  description = "S3 repository key of Chef cookbooks for ArcGIS distribution archive in the repository bucket"
  type        = string
  default     = "cookbooks/arcgis-5.1.0-cookbooks.tar.gz"

  validation {
    condition     = can(regex("^[a-zA-Z0-9!_.*'()-]+(\\/[a-zA-Z0-9!_.*'()-]+)*$", var.arcgis_cookbooks_path))
    error_message = "The s3_key value must be in a valid S3 key format."
  }
}
