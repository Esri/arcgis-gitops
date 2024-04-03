variable "controller_version" {
  description = "Version of the AWS Load Balancer Controller"
  type        = string
  default     = "2.7.0"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "oidc_arn" {
  description = "OIDC provider ARN for the EKS cluster"
  type        = string
}

variable "enable_waf" {
  description = "Enable WAF and Shield addons for ALB"
  type        = bool
  default     = true
}

variable "copy_image" {
  description = "If set to true, the controller's image is copied to the private ECR repository"
  type        = bool
  default     = false
}
