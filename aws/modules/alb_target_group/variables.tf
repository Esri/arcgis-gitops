# Copyright 2024-2025 Esri
#
# Licensed under the Apache License Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

variable "name" {
  description = "Target group name"
  type        = string
  default     = null
}

variable "protocol" {
  description = "Target group protocol"
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS", "TCP"], var.protocol)
    error_message = "Valid values for protocol variable are: HTTP, HTTPS, TCP."
  }
}

variable "alb_port" {
  description = "Target group port"
  type        = number
  default     = 80
}

variable "instance_port" {
  description = "Instance port"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/server/rest/info/healthcheck"
}

variable "path_patterns" {
  description = "Listener rule path patterns"
  type        = list(string)
  default     = ["/portal", "/portal/*", "/server", "/server/*"]
}

variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "alb_arn" {
  description = "Application Load Balancer ARN"
  type        = string
}

variable "target_instances" {
  description = "List of target EC2 instance Ids"
  type        = list(string)
}

variable "priority" {
  description = "Target group priority"
  type = number
  default = 100
}