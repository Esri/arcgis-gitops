variable "bucket_name" {
  description = "S3 bucket name"
  type = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "The bucket_name value must be between 3 and 63 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
} 

variable "index_file" {
  description = "Index file local path"
  type = string
} 

variable "arcgis_online_username" {
  description = "ArcGIS Online user name"
  type = string
  default = null
}

variable "arcgis_online_password" {
  description = "ArcGIS Online user password"
  type = string
  sensitive = true
  default = null
}
