variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "deployment_id" {
  description = "ArcGIS Enterprise deployment Id"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.deployment_id))
    error_message = "The deployment_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "machine_roles" {
  description = "List of machine roles."
  type = list(string)
}   

variable "parameter_name" {
  description = "Name of the SSM parameter to store the value of json_attributes variable"
  type = string   

  validation {
    condition     = can(regex("^[a-zA-Z0-9\\/_.-]*$", var.parameter_name))
    error_message = "The parameter_name value must can include only the slash (/) character and following symbols and letters: a-zA-Z0-9_.-."
  }
}

variable json_attributes {
  description = "Chef run attributes in JSON format"
  type = string
  sensitive = true
}

variable "execution_timeout" {
  description = "Chef run timeout in seconds"
  type = number
  default = 3600 # 1 hour
}
