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

output "resource_group_name" {
  description = "Resource Group Name"
  value       = "${var.site_id}-infrastructure-core"
}

output "vault_name" {
  description = "Azure Key Vault Name"
  value       = data.azurerm_key_vault.site_vault.name
}

output "vault_id" {
  description = "Azure Key Vault Id"
  value       = data.azurerm_key_vault.site_vault.id
}

output "vault_uri" {
  description = "Azure Key Vault URI"
  value       = data.azurerm_key_vault.site_vault.vault_uri
}

output "vnet_id" {
  description = "VNet Id of ArcGIS Enterprise site"
  value       = data.azurerm_key_vault_secret.vnet_id.value
}

output "app_gateway_subnets" {
  description = "Ids of app gateway subnets"
  value       = jsondecode(data.azurerm_key_vault_secret.subnets.value).app_gateway
}

output "private_subnets" {
  description = "Ids of private subnets"
  value       = jsondecode(data.azurerm_key_vault_secret.subnets.value).private
}

output "internal_subnets" {
  description = "Ids of internal subnets"
  value       = jsondecode(data.azurerm_key_vault_secret.subnets.value).internal
}

output "storage_account_name" {
  description = "Azure storage account name"
  value       = data.azurerm_key_vault_secret.storage_account_name.value
}

output "storage_account_id" {
  description = "Azure storage account Id"
  value       = data.azurerm_storage_account.site_storage.id
}

output "storage_account_blob_endpoint" {
  description = "Azure storage account primary blob endpoint"
  value       = data.azurerm_storage_account.site_storage.primary_blob_endpoint
}
