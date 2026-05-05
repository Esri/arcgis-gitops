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

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment ID"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,25}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 25 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "enterprise_id" {
  description = "ArcGIS Enterprise ID"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,6}$", var.enterprise_id))
    error_message = "The enterprise_id value must be between 3 and 6 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "execution_timeout" {
  description = "Chef run timeout in seconds"
  type = number
  default = 3600 # 1 hour
}

variable json_attributes {
  description = "Chef run attributes in JSON format"
  type = string
  sensitive = true
}

variable "json_attributes_secret" {
  description = "Key Vault secret name of role attributes"
  type = string   

  validation {
    condition     = can(regex("^[a-zA-Z0-9\\/_.-]*$", var.json_attributes_secret))
    error_message = "The json_attributes_secret value can include only the slash (/) character and the following symbols and letters: a-zA-Z0-9_.-."
  }
}

variable "machine_roles" {
  description = "List of machine roles."
  type = list(string)
}   
