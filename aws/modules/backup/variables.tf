# Copyright 2025 Esri
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

variable "arcgis_application" {
  description = "ArcGIS Enterprise application type (server|notebook-store)"
  type        = string
  default     = "server"

  validation {
    condition     = contains(["server", "notebook-server"], var.arcgis_application)
    error_message = "Valid values for arcgis_application variable are server and notebook-server."
  }
}

variable "arcgis_version" {
  description = "ArcGIS Enterprise version"
  type        = string
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "enterprise-base-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
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

# In ArcGIS Server 12.0 and later the config store S3 bucket must be pre-created.
variable "backup_s3_bucket" {
  description = "Backup the config store S3 bucket"
  type        = bool
  default     = false
}
