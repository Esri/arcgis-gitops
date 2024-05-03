variable "command" {
  description = "The CLI command and arguments to run"
  type        = list(string)
}


variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "admin_cli_pod" {
  description = "Enterprise Admin CLI pod name"
  type        = string
  default     = "enterprise-admin-cli"
}
