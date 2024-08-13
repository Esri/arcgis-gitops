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

variable "os" {
  description = "Operating system id (rhel8|rhel9|ubuntu20|ubuntu22|sles15)"
  type        = string
  default     = "rhel8"

  validation {
    condition     = contains(["rhel8", "rhel9", "ubuntu20", "ubuntu22", "sles15"], var.os)
    error_message = "Valid values for os variable are rhel8, rhel9, ubuntu20, ubuntu22, and sles15."
  }
}

variable "deployment_fqdn" {
  description = "Fully qualified domain name of the base ArcGIS Enterprise deployment"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn))
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
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

variable "deployment_id" {
  description = "Deployment Id"
  type        = string
  default     = "arcgis-enterprise-base"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "arcgis_version" {
  description = "ArcGIS Enterprise version"
  type        = string
  default     = "11.3"

  validation {
    condition     = contains(["11.0", "11.1", "11.2", "11.3"], var.arcgis_version)
    error_message = "Valid values for arcgis_version variable are 11.0, 11.1, 11.2, and 11.3."
  }
}

variable "is_upgrade" {
  description = "Flag to indicate if this is an upgrade deployment"
  type        = bool
  default     = false
}

variable "run_as_user" {
  description = "User name for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store."
  type        = string
  default     = "arcgis"
}

variable "java_version" {
  description = "OpenJDK version"
  type        = string
  default     = "11.0.20"
}

variable "tomcat_version" {
  description = "Apache Tomcat version"
  type        = string
  default     = "9.0.48"
}

variable "server_authorization_file_path" {
  description = "Local path of ArcGIS Server authorization file"
  type        = string
}

variable "server_authorization_options" {
  description = "Additional ArcGIS Server software authorization command line options"
  type        = string
  sensitive   = true
  default     = ""
}

variable "portal_authorization_file_path" {
  description = "Local path of Portal for ArcGIS authorization file"
  type        = string
}

variable "portal_user_license_type_id" {
  description = "Portal for ArcGIS administrator user license type Id"
  type        = string
  default     = ""
}

variable "keystore_file_path" {
  description = "Local path of keystore file in PKCS12 format with SSL certificate used by HTTPS listeners"
  type        = string
  default     = null
}

variable "keystore_file_password" {
  description = "Password for keystore file with SSL certificate used by HTTPS listeners"
  type        = string
  sensitive   = true
  default     = ""
}

variable "root_cert_file_path" {
  description = "Local path of root certificate file in PEM format used by ArcGIS Server and Portal for ArcGIS"
  type        = string
  default     = null
}

variable "admin_username" {
  description = "Primary ArcGIS Enterprise administrator user name"
  type        = string
  default     = "siteadmin"

  validation {
    condition     = can(regex("^[a-zA-Z0-9.]{6,128}$", var.admin_username))
    error_message = "The admin_username value must be between 6 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.)."
  }
}

variable "admin_password" {
  description = "Primary ArcGIS Enterprise administrator user password"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-zA-Z0-9.]{8,128}$", var.admin_password))
    error_message = "The admin_password value must be between 8 and 128 characters long and can consist only of uppercase and lowercase ASCII letters, numbers, and dots (.)."
  }
}

variable "admin_email" {
  description = "Primary ArcGIS Enterprise administrator e-mail address"
  type        = string
}

variable "admin_full_name" {
  description = "Primary ArcGIS Enterprise administrator full name"
  type        = string
  default     = "Administrator"
}

variable "admin_description" {
  description = "Primary ArcGIS Enterprise administrator description"
  type        = string
  default     = "Initial account administrator"
}

variable "security_question" {
  description = "Primary ArcGIS Enterprise administrator security question"
  type        = string
  default     = "What city were you born in?"

  validation {
    condition = can(contains([
      "What city were you born in?",
      "What was your high school mascot?",
      "What is your mother's maiden name?",
      "What was the make of your first car?",
      "What high school did you go to?",
      "What is the last name of your best friend?",
      "What is the middle name of your youngest sibling?",
      "What is the name of the street on which you grew up?",
      "What is the name of your favorite fictional character?",
      "What is the name of your favorite pet?",
      "What is the name of your favorite restaurant?",
      "What is the title of your favorite book?",
      "What is your dream job?",
      "Where did you go on your first date?"
    ], var.security_question))
    error_message = "The security_question value must be one of the allowed security questions."
  }
}

variable "security_question_answer" {
  description = "Primary ArcGIS Enterprise administrator security question answer"
  type        = string
  sensitive   = true
}

variable "log_level" {
  description = "ArcGIS Enterprise applications log level"
  type        = string
  default     = "WARNING"
  validation {
    # Log levels supported by both ArcGIS Server and Portal for ArcGIS
    condition     = contains(["SEVERE", "WARNING", "INFO", "FINE", "VERBOSE", "DEBUG"], var.log_level)
    error_message = "Valid values for the log_level variable are SEVERE, WARNING, INFO, FINE, VERBOSE, and DEBUG"
  }
}

variable "arcgis_portal_patches" {
  description = "File names of Portal for ArcGIS patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_server_patches" {
  description = "File names of ArcGIS Server patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_data_store_patches" {
  description = "File names of ArcGIS Data Store patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_web_adaptor_patches" {
  description = "File names of ArcGIS Web Adaptor patches to install."
  type        = list(string)
  default     = []
}

variable "arcgis_online_username" {
  description = "ArcGIS Online user name"
  type        = string
  default     = null
}

variable "arcgis_online_password" {
  description = "ArcGIS Online user password"
  type        = string
  sensitive   = true
  default     = null
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