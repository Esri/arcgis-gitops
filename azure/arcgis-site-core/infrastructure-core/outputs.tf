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

output "vnet_id" {
  description = "ArcGIS Enterprise site virtual network Id"
  value       = azurerm_virtual_network.site_vnet.id
}

output "app_gateway_subnets" {
  description = "Application Gateway subnets Ids"
  value       = azurerm_subnet.app_gateway_subnets.*.id
}

output "private_subnets" {
  description = "Private subnets Ids"
  value       = azurerm_subnet.private_subnets.*.id
}

output "internal_subnets" {
  description = "Internal subnets Ids"
  value       = azurerm_subnet.internal_subnets.*.id
}

output "key_vault_id" {
  description = "Key Vault Id"
  value       = azurerm_key_vault.site_vault.id
}

output "storage_account_id" {
  description = "Storage account Id"
  value       = azurerm_storage_account.site_storage.id
}

# output "private_dns_zones" {
#   description = "Ids of Private DNS Zones"
#   value       = azurerm_private_dns_zone.dns.*.id
# }
