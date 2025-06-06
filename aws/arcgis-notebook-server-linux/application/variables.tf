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

variable "admin_email" {
  description = "ArcGIS Notebook Server administrator e-mail address"
  type        = string
}

variable "admin_password" {
  description = "Primary ArcGIS Notebook Server administrator user password"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9.]{8,128}$", var.admin_password))
    error_message = "The admin_password value must be between 8 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.)."
  }
}

variable "admin_username" {
  description = "Primary ArcGIS Notebook Server administrator user name"
  type        = string
  default     = "siteadmin"

  validation {
    condition     = can(regex("^[a-zA-Z0-9.]{6,128}$", var.admin_username))
    error_message = "The admin_username value must be between 6 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.)."
  }
}

variable "arcgis_notebook_server_patches" {
  description = "File names of ArcGIS Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_version" {
  description = "ArcGIS Notebook Server version"
  type        = string
  default     = "11.5"

  validation {
    condition     = contains(["11.4", "11.5"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.4 and 11.5."
  }
}

variable "arcgis_web_adaptor_patches" {
  description = "File names of ArcGIS Web Adaptor patches to install."
  type        = list(string)
  default     = []
}

variable "aws_region" {
  description = "AWS region Id"
  type        = string
}

variable "config_store_type" {
  description = "ArcGIS Server configuration store type"
  type        = string
  default     = "FILESYSTEM"

  validation {
    condition     = contains(["FILESYSTEM", "AMAZON"], var.config_store_type)
    error_message = "Valid values for the config_store_type variable are FILESYSTEM and AMAZON"
  }
}

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "notebook-server-linux"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "is_upgrade" {
  description = "Flag to indicate if this is an upgrade deployment"
  type        = bool
  default     = false
}

variable "keystore_file_password" {
  description = "Password for keystore file with SSL certificate used by HTTPS listeners"
  type        = string
  sensitive   = true
  default     = ""
}

variable "keystore_file_path" {
  description = "Local path of keystore file in PKCS12 format with SSL certificate used by HTTPS listeners"
  type        = string
  default     = null
}

variable "license_level" {
  description = "ArcGIS Notebook Server license level"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "advanced"], var.license_level)
    error_message = "Valid values for license_level variable are standard and advanced."
  }
}

variable "log_level" {
  description = "ArcGIS Notebook Server log level"
  type        = string
  default     = "WARNING"
  validation {
    condition     = contains(["SEVERE", "WARNING", "INFO", "FINE", "VERBOSE", "DEBUG"], var.log_level)
    error_message = "Valid values for the log_level variable are SEVERE, WARNING, INFO, FINE, VERBOSE, and DEBUG"
  }
}

variable "notebook_server_authorization_file_path" {
  description = "Local path of ArcGIS Notebook Server authorization file"
  type        = string
}

variable "notebook_server_authorization_options" {
  description = "Additional ArcGIS Notebook Server software authorization command line options"
  type        = string
  sensitive   = true
  default     = ""
}

variable "os" {
  description = "Operating system id (rhel9|ubuntu22)"
  type        = string
  default     = "rhel9"

  validation {
    condition     = contains(["rhel9", "ubuntu22"], var.os)
    error_message = "Valid values for os variable are rhel9 and ubuntu22."
  }
}

variable "portal_org_id" {
  description = "ArcGIS Enterprise organization Id"
  type        = string
  default     = null
}

variable "portal_password" {
  description = "Portal for ArcGIS user password"
  type        = string
  sensitive   = true
  default     = null
}

variable "portal_url" {
  description = "Portal for ArcGIS URL"
  type        = string
  default     = null
}

variable "portal_username" {
  description = "Portal for ArcGIS user name"
  type        = string
  default     = null
}

variable "root_cert_file_path" {
  description = "Local path of root certificate file in PEM format used by ArcGIS Server and Portal for ArcGIS"
  type        = string
  default     = null
}

variable "run_as_user" {
  description = "User name for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store."
  type        = string
  default     = "arcgis"
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