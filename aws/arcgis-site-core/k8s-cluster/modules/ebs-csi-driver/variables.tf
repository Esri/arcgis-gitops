variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "oidc_arn" {
  description = "The OIDC provider ARN for the EKS cluster"
  type        = string
}
