variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Deployment namespace"
  type        = string
}

variable "admin_email" {
  description = "ArcGIS Enterprise on Kubernetes organization administrator account email"
  type        = string
}
