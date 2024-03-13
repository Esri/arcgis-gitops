variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "eks_version" {
  description = "The desired Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.eks_version))
    error_message = "The eks_version value must be in the format of major.minor, for example, 1.29"
  }
}

variable "node_groups" {
  description = "EKS Node Groups configuration"
  type = list(object({
    name             = string
    instance_type    = string
    root_volume_size = number
    desired_size     = number
    max_size         = number
    min_size         = number
  }))
  default = [
    {
      name             = "default"
      instance_type    = "m6i.2xlarge"
      root_volume_size = 1024
      desired_size     = 4
      max_size         = 8
      min_size         = 4
    }
  ]
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = null
}
