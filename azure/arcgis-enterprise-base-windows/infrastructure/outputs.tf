# Copyright 2025-2026 Esri
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

output "fileserver_security_group_id" {
  description = "Subnet network security group ID shared by the Windows file server, primary and standby VMs"
  value       = module.azvm_fileserver.security_group_id
}

output "fileserver_private_dns" {
  description = "Private DNS name of the dedicated Windows file-server VM"
  value       = module.azvm_fileserver.private_dns
}

output "fileserver_recovery_vault_name" {
  description = "Recovery Services vault protecting the dedicated Windows file-server VM"
  value       = azurerm_recovery_services_vault.deployment.name
}

output "deployment_url" {
  description = "Portal for ArcGIS URL"
  value       = "https://${local.ingress_fqdn}/${local.portal_web_context}"
}

