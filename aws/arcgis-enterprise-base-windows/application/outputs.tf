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
 
output "arcgis_server_url" {
  description = "ArcGIS Server URL"
  value       = "https://${var.deployment_fqdn}/${var.server_web_context}"
}

output "arcgis_portal_url" {
  description = "Portal for ArcGIS URL"
  value       = "https://${var.deployment_fqdn}/${var.portal_web_context}"
}

output "arcgis_server_private_url" {
  description = "ArcGIS Server private URL"
  value       = "https://${var.deployment_fqdn}:6443/arcgis"
}

output "arcgis_portal_private_url" {
  description = "Portal for ArcGIS private URL"
  value       = "https://${var.deployment_fqdn}:7443/arcgis"
}
