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

# Storage account and blob containers for ArcGIS Enterprise site

resource "random_id" "storage_account_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new site id
    site_id = var.site_id
  }

  byte_length = 8
}

resource "azurerm_storage_account" "site_storage" {
  name                     = "site${random_id.storage_account_suffix.hex}"
  resource_group_name      = azurerm_resource_group.site_rg.name
  location                 = azurerm_resource_group.site_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_storage_container" "repository" {
  name                  = "repository"
  storage_account_name  = azurerm_storage_account.site_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.site_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_name  = azurerm_storage_account.site_storage.name
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.site_storage.name
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [ 
    azurerm_key_vault_access_policy.current_user
  ]
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.site_storage.primary_access_key
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [ 
    azurerm_key_vault_access_policy.current_user
  ]
}
