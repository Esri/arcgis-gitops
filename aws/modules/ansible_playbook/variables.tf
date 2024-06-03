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

variable "playbook" {
  description = "Ansible playbook"
  type = string
}

variable external_vars {
  description = "Ansible external vars"
  type = any
  sensitive = true
}
