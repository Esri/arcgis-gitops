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
 
output "alb_arn" {
  description = "Application Load Balancer ARN"
  value = data.aws_lb.arcgis_enterprise_ingress.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value = data.aws_lb.arcgis_enterprise_ingress.dns_name
}

output "alb_zone_id" {
  description = "Application Load Balancer zone ID"
  value = data.aws_lb.arcgis_enterprise_ingress.zone_id
}