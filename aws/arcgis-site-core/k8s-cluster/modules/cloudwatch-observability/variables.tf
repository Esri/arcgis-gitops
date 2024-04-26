variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "log_retention" {
  description = "The number of days to retain log events"
  type        = number
  default     = 90
}

variable "container_logs_enabled" {
  description = "Whether to enable container logs"
  type        = bool
  default     = true
}