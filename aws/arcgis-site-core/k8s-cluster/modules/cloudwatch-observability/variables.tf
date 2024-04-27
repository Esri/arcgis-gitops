variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "container_logs_enabled" {
  description = "Whether to enable container logs"
  type        = bool
  default     = true
}