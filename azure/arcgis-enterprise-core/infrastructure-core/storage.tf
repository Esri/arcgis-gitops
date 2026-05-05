# Copyright 2024-2026 Esri
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

# Storage account and blob containers for ArcGIS Enterprise

locals {
  blob_private_dns_zone_index = try(index(var.private_dns_zones, "privatelink.blob.core.windows.net"), -1)
}

# Create storage account for the enterprise's repository, backups, and logs.
# Public network access is enabled for the storage account because it is required
# to create the blob containers.
resource "azurerm_storage_account" "enterprise_storage" {
  name                          = "${var.enterprise_id}${random_id.unique_name_suffix.hex}"
  resource_group_name           = azurerm_resource_group.enterprise_rg.name
  location                      = azurerm_resource_group.enterprise_rg.location
  account_tier                  = "Standard"
  account_replication_type      = "GRS"
  public_network_access_enabled = true
  # Shared access key is required for ArcGIS Data Store backup
  # shared_access_key_enabled     = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
  }
}

# Assign Storage Blob Data Contributor role to the current user identity
resource "azurerm_role_assignment" "storage_account_owner" {
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.enterprise_storage.id
  skip_service_principal_aad_check = true
}

resource "azurerm_storage_container" "repository" {
  name                  = "repository"
  storage_account_id    = azurerm_storage_account.enterprise_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.enterprise_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "content_backups" {
  name                  = "content-backups"
  storage_account_id    = azurerm_storage_account.enterprise_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "webgisdr_backups" {
  name                  = "webgisdr-backups"
  storage_account_id    = azurerm_storage_account.enterprise_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "datastore_backups" {
  name                  = "datastore-backups"
  storage_account_id    = azurerm_storage_account.enterprise_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "k8s_backups" {
  name                  = "k8s-backups"
  storage_account_id    = azurerm_storage_account.enterprise_storage.id
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.enterprise_storage.name
  key_vault_id = azurerm_key_vault.enterprise_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  value        = azurerm_storage_account.enterprise_storage.primary_access_key
  key_vault_id = azurerm_key_vault.enterprise_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

# Create image gallery for the enterprise's VM images

resource "azurerm_shared_image_gallery" "enterprise_ig" {
  name                = "${var.enterprise_id}${random_id.unique_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.enterprise_rg.name
  location            = azurerm_resource_group.enterprise_rg.location
  description         = "ArcGIS Enterprise image gallery"
  
  tags = {
    ArcGISEnterpriseID = var.enterprise_id
  }
}

resource "azurerm_key_vault_secret" "enterprise_ig" {
  name         = "image-gallery-name"
  value        = azurerm_shared_image_gallery.enterprise_ig.name
  key_vault_id = azurerm_key_vault.enterprise_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

# Create azure private endpoint for the enterprise storage account and link it to the blob private DNS zone

resource "azurerm_private_endpoint" "enterprise_store_private_endpoint" {
  count               = local.blob_private_dns_zone_index >= 0 ? 1 : 0
  name                = "${azurerm_storage_account.enterprise_storage.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.enterprise_rg.name
  location            = var.azure_region
  subnet_id           = azurerm_subnet.private_subnets[0].id

  private_service_connection {
    name                           = "${azurerm_storage_account.enterprise_storage.name}-service-connection"
    private_connection_resource_id = azurerm_storage_account.enterprise_storage.id
    is_manual_connection           = false
    subresource_names = [
      "blob"
    ]
  }

  private_dns_zone_group {
    name = "${azurerm_storage_account.enterprise_storage.name}-private-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.private_dns_zones[local.blob_private_dns_zone_index].id
    ]
  }

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
  }
}
