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
 
variable "admin_password" {
  description = "Portal for ArcGIS administrator user password"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9.]{8,128}$", var.admin_password))
    error_message = "The admin_password value must be between 8 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.)."
  }
}

variable "admin_username" {
  description = "Portal for ArcGIS administrator user name"
  type        = string
  default     = "siteadmin"

  validation {
    condition     = can(regex("^[a-zA-Z0-9.]{6,128}$", var.admin_username))
    error_message = "The admin_username value must be between 6 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.)."
  }
}

variable "backup_restore_mode" {
  description = "Type of backup"
  type        = string
  default     = "backup"
  validation {
    condition     = contains(["backup", "full", "incremental"], var.backup_restore_mode)
    error_message = "Valid values for the backup_restore_mode variable are backup, full, and incremental"
  }
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "arcgis-enterprise-base"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "execution_timeout" {
  description = "Execution timeout in seconds"
  type        = number
  default     = 36000 # 10 hours

  validation {
    condition     = var.execution_timeout > 0 && var.execution_timeout <= 172800
    error_message = "The execution_timeout value must be greater than 0 and less then or equal to 172800."
  }
}

variable "portal_admin_url" {
  description = "Portal for ArcGIS administrative URL"
  type        = string
  default     = "https://localhost:7443/arcgis"

  validation {
    condition     = can(regex("^(((http|https):\\/\\/)|(\\/)|(..\\/))(\\w+:{0,1}\\w*@)?(\\S+)(:[0-9]+)?(\\/|\\/([\\w#!:.?+=&%@!\\-\\/]))?$", var.portal_admin_url))
    error_message = "The portal_admin_url value must be a valid HTTP or HTTPS URL."
  }
}

variable "run_as_password" {
  description = "Password for the account used to run Portal for ArcGIS"
  type        = string
  sensitive   = true
}

variable "run_as_user" {
  description = "User name for the account used to run Portal for ArcGIS"
  type        = string
  default     = "arcgis"
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
