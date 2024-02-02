variable "name" {
  description = "Security group name"
  type = string
} 

variable "vpc_id" {
  description = "VPC Id"
  type = string
}

variable "alb_security_group_id" {
  description = "Security group Id of Application Load Balancer"
  type = string
}

variable "alb_ports" {
  description = "Ports used by Application Load Balancer"
  type = list(number)
  default = [ 80, 443 ]
}
