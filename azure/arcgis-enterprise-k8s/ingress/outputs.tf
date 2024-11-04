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

output "alb_dns_name" {
  description = "FQDN of the Application Gateway frontend"
  value       = azurerm_application_load_balancer_frontend.deployment_frontend.fully_qualified_domain_name
}

output "deployment_url" {
  description = "URL of the ArcGIS Enterprise on Kubernetes deployment"
  value       = "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}"
}
