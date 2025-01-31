# Copyright 2024-2025 Esri
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

variable "azure_region" {
  description = "Azure region display name"
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

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment Id"
  type        = string
  default     = "arcgis-enterprise-k8s"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "helm_charts_version" {
  description = "Helm Charts for ArcGIS Enterprise on Kubernetes version"
  type        = string
  default     = "1.4.0"
}

variable "upgrade_token" {
  description = "ArcGIS Enterprise organization administrator account token"
  type        = string
  sensitive   = true
  default     = "add_token_here"
}

variable "mandatory_update_target_id" {
  description = "Patch ID of required update"
  type        = string
  default     = ""
}

variable "image_repository_prefix" {
  description = "Prefix of images in ECR repositories"
  type        = string
  default     = "docker-hub/esridocker"
}

variable "deployment_fqdn" {
  description = "The fully qualified domain name (FQDN) to access ArcGIS Enterprise on Kubernetes"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.deployment_fqdn))
    error_message = "The deployment_fqdn value must be a valid domain name."
  }
}

variable "arcgis_enterprise_context" {
  description = "Context path to be used in the URL for ArcGIS Enterprise on Kubernetes"
  type        = string
  default     = "arcgis"
  
  validation {
    condition     = can(regex("^[a-z0-9]{1,}$", var.arcgis_enterprise_context))
    error_message = "The arcgis_enterprise_context value must be an alphanumeric string."
  }  
}

variable "k8s_cluster_domain" {
  description = "Kubernetes cluster domain"
  type        = string
  default     = "cluster.local"
}

variable "common_verbose" {
  description = "Enable verbose install logging"
  type        = bool
  default     = false
}

# Application configuration variables

variable "configure_enterprise_org" {
  description = "Configure ArcGIS Enterprise on Kubernetes organization"
  type        = bool
  default     = true
}

variable "configure_wait_time_min" {
  description = "Organization admin URL validation timeout in minutes"
  type = number
  default = 15
}

variable "system_arch_profile" {
  description = "ArcGIS Enterprise on Kubernetes architecture profile"
  type        = string
  default     = "standard-availability"

  validation {
    condition     = can(regex("^(development|standard-availability|enhanced-availability)$", var.system_arch_profile))
    error_message = "The system_arch_profile value must be either development, standard-availability, or enhanced-availability."
  }
}

variable "authorization_file_path" {
  description = "ArcGIS Enterprise on Kubernetes authorization file path"
  type        = string
}

variable "license_type_id" {
  description = "User type ID for the primary administrator account"
  type        = string
  default     = "creatorUT"
}

variable "admin_username" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account username"
  type        = string
  default     = "siteadmin"

  validation {
    condition     = can(regex("^[-a-zA-Z0-9@_.]{6,}$", var.admin_username))
    error_message = "The admin_username value must be at least six characters in length. The only special characters allowed are the at sign (@), dash (-), dot (.), and underscore (_)."
  }
}

variable "admin_password" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "The admin_password value must be at least eight characters in length."
  }

  validation {
    condition     = can(regex("[A-Za-z]", var.admin_password))
    error_message = "The admin_password value must contain at least one alphabet letter (uppercase or lowercase)."
  }

  validation {
    condition     = can(regex("\\d", var.admin_password))
    error_message = "The admin_password value must contain at least one digit."
  }

  validation {
    condition     = can(regex("[^A-Za-z0-9]", var.admin_password))
    error_message = "The admin_password value must contain at least one special character."
  }
}

variable "admin_email" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account email"
  type        = string
}

variable "admin_first_name" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account first name"
  type        = string
}

variable "admin_last_name" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account last name"
  type        = string
}

variable "security_question_index" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account security question index"
  type        = number
  default     = 1

  validation {
    condition = var.security_question_index > 0 &&  var.security_question_index < 15
    error_message = "The security_question_index value must be an number between 1 and 14."
  }
}

variable "security_question_answer" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account security question answer"
  type        = string
  sensitive   = true
}

variable "cloud_config_json_file_path" {
  description = "ArcGIS Enterprise on Kubernetes cloud configuration JSON file path"
  type        = string
  default     = null
}

variable "log_setting" {
  description = "ArcGIS Enterprise on Kubernetes log level"
  type        = string
  default     = "INFO"

  validation {
    condition     = can(regex("^(SEVERE|WARNING|INFO|FINE|VERBOSE|DEBUG)$", var.log_setting))
    error_message = "The log_setting value must be either SEVERE, WARNING, INFO, FINE, VERBOSE, DEBUG."
  }
}

variable "log_retention_max_days" {
  description = "Number of days logs will be retained by the organization"
  type        = number
  default     = 60
  validation {
    condition     = var.log_retention_max_days > 0 && var.log_retention_max_days < 1000
    error_message = "The log_retention_max_days value must be a number between 1 and 999."
  }
}

variable "staging_volume_class" {
  description = "Staging volume storage class"
  type        = string
  default     = "managed-premium"
}

variable "staging_volume_size" {
  description = "Staging volume size"
  type        = string
  default     = "64Gi"
}

variable "backup_job_timeout" {
  description = "Backup job timeout in seconds"
  type        = number
  default     = 7200
}

variable "enterprise_admin_cli_version" {
  description = "ArcGIS Enterprise Admin CLI image tag"
  type        = string
  default     = "0.4.0"
}

variable "storage" {
  description = "Storage properties for the data stores"
  type = map(object({
    type   = string
    size   = string
    class  = string
    label1 = string
    label2 = string
  }))
  default = {
    relational = {
      type   = "DYNAMIC"
      size   = "16Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
    object = {
      type   = "DYNAMIC"
      size   = "32Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
    memory = {
      type   = "DYNAMIC"
      size   = "16Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
    queue = {
      type   = "DYNAMIC"
      size   = "16Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
    indexer = {
      type   = "DYNAMIC"
      size   = "16Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
    sharing = {
      type   = "DYNAMIC"
      size   = "16Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
    prometheus = {
      type   = "DYNAMIC"
      size   = "30Gi"
      class  = "managed-premium"
      label1 = ""
      label2 = ""
    }
  }
}
