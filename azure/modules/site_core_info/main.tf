/*
 * # Terraform module site_core_info
 * 
 * Terraform module site_core_info retrieves names and Ids of core Azure resources
 * created by infrastructure-core module from Azure Key Vault and
 * returns them as output values. 
 */

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

data "azurerm_resources" "site_vault" {
  resource_group_name = "${var.site_id}-infrastructure-core"

  required_tags = {
    ArcGISSiteId = var.site_id
    ArcGISRole   = "site-vault"
  }
}

data "azurerm_key_vault" "site_vault" {
  name                = data.azurerm_resources.site_vault.resources[0].name
  resource_group_name = data.azurerm_resources.site_vault.resource_group_name
}

data "azurerm_key_vault_secret" "subnets" {
  name         = "subnets"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

data "azurerm_key_vault_secret" "vnet_id" {
  name         = "vnet-id"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

data "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

data "azurerm_key_vault_secret" "storage_account_name" {
  name         = "storage-account-name"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

data "azurerm_storage_account" "site_storage" {
  name                = data.azurerm_key_vault_secret.storage_account_name.value
  resource_group_name = "${var.site_id}-infrastructure-core"
}
