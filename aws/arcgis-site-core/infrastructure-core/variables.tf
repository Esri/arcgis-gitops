variable "site_id" {
  description = "ArcGIS Enterprise site Id"
  type        = string
  default     = "arcgis-enterprise"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,23}$", var.site_id))
    error_message = "The site_id value must be between 3 and 23 characters long and can consist only of lowercase letters, numbers, and hyphens (-)."
  }
}

variable "hosted_zone_name" {
  description = "Private hosted zone name"
  type        = string
  default     = "arcgis-enterprise.internal"

  validation {
    condition     = can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.hosted_zone_name))
    error_message = "The hosted_zone_name value must be a valid domain name."
  }
}

variable "availability_zones" {
  description = "AWS availability zones (if the list contains less that two elements, the first two available availability zones in the AWS region will be used.)"
  type        = list(string)
  default     = []
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.vpc_cidr_block))
    error_message = "The vpc_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "public_subnet1_cidr_block" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.public_subnet1_cidr_block))
    error_message = "The public_subnet1_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "public_subnet2_cidr_block" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.public_subnet2_cidr_block))
    error_message = "The public_subnet2_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "private_subnet1_cidr_block" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.private_subnet1_cidr_block))
    error_message = "The private_subnet1_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "private_subnet2_cidr_block" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.0.3.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.private_subnet2_cidr_block))
    error_message = "The private_subnet2_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "isolated_subnet1_cidr_block" {
  description = "CIDR block for isolated subnet 1"
  type        = string
  default     = "10.0.4.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.isolated_subnet1_cidr_block))
    error_message = "The isolated_subnet1_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "isolated_subnet2_cidr_block" {
  description = "CIDR block for isolated subnet 2"
  type        = string
  default     = "10.0.5.0/24"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}\\/[0-9]{1,2}$", var.isolated_subnet2_cidr_block))
    error_message = "The isolated_subnet2_cidr_block value must be in IPv4 CIDR block format."
  }
}

variable "isolated_subnets" {
  description = "Create isolated subnets and VPC endpoints"
  type        = bool
  default     = false
}
