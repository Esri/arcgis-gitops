# Copyright 2024 Esri
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
