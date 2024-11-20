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

# Create storage account for the site's repository, backups, and logs.
# Public network access is enabled for the storage account because it is required
# to create the blob containers.
resource "azurerm_storage_account" "site_storage" {
  name                            = "site${random_id.storage_account_suffix.hex}"
  resource_group_name             = azurerm_resource_group.site_rg.name
  location                        = azurerm_resource_group.site_rg.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  public_network_access_enabled   = true
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_storage_container" "repository" {
  name                  = "repository"
  storage_account_id    = azurerm_storage_account.site_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.site_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_id    = azurerm_storage_account.site_storage.id
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

# Create azure private endpoint for the blob store

resource "azurerm_private_dns_zone" "blob_private_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.site_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_private_dns_zone_virtual_network_link" {
  name                  = "blob-private-dns-zone-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.blob_private_dns_zone.name
  resource_group_name   = azurerm_resource_group.site_rg.name
  virtual_network_id    = azurerm_virtual_network.site_vnet.id
}

resource "azurerm_private_endpoint" "site_store_private_endpoint" {
  name                = "${azurerm_storage_account.site_storage.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.site_rg.name
  location            = var.azure_region
  subnet_id           = azurerm_subnet.internal_subnets[0].id

  private_service_connection {
    name                           = "${azurerm_storage_account.site_storage.name}-service-connection"
    private_connection_resource_id = azurerm_storage_account.site_storage.id
    is_manual_connection           = false
    subresource_names = [
      "blob"
    ]
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.site_storage.name}-private-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.blob_private_dns_zone.id
    ]
  }

  tags = {
    ArcGISSiteId = var.site_id
  }
}
