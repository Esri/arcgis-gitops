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
 
output "security_group_id" {
  description = "EC2 security group Id"
  value       = module.security_group.id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.alb.alb_dns_name
}

output "deployment_url" {
  description = "Portal for ArcGIS URL of the deployment"
  value       = "https://${var.deployment_fqdn}/${var.portal_web_context}"
}
