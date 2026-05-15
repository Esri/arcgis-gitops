/*
* # Terraform module aznfs_fileserver
 * 
 * Terraform module creates or references an NFS file share for the deployment's file server.
 *
 * If `fileserver_deployment_id` variable is null, the module creates a new storage account and an NFS file share. 
 * 
 * If `fileserver_deployment_id` variable is not null, the module reads the NFS file share network path from Key Vault secrets for the specified deployment.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Azure credentials must be configured using "az login" CLI command
 *
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 *
 * | Secret Name                             | Description |
 * |-----------------------------------------|-------------|
 * | ${var.fileserver_deployment_id}-aznfs-network-path | Network path for the NFS file share (if ${var.fileserver_deployment_id} is not null) |
 *
 * ### Secrets Written by the Module
 *
 * | Secret Name                               | Description |
 * |-------------------------------------------|-------------|
 * | ${var.deployment_id}-aznfs-network-path   | Network path for the NFS file share (if ${var.fileserver_deployment_id} is null) |
 */

# Copyright 2026 Esri
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

data "azurerm_private_dns_zone" "privatelink_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = "${var.enterprise_id}-infrastructure-core"
}

data "azurerm_key_vault_secret" "aznfs_network_path" {
  count        = var.fileserver_deployment_id != null ? 1 : 0

  name         = "${var.fileserver_deployment_id}-aznfs-network-path"
  key_vault_id = var.key_vault_id
}

locals {
  aznfs_network_path = var.fileserver_deployment_id != null ? data.azurerm_key_vault_secret.aznfs_network_path[0].value : "${azurerm_storage_account.file_store[0].name}.file.core.windows.net:/${azurerm_storage_account.file_store[0].name}/${azurerm_storage_share.fileserver[0].name}"
}

# Storage Account with NFS File Share for fileserver
resource "azurerm_storage_account" "file_store" {
  count              = var.fileserver_deployment_id == null ? 1 : 0

  name                = "nfs${var.unique_name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = var.storage_replication_type

  https_traffic_only_enabled = false
  is_hns_enabled             = false

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [var.subnet_id]
  }

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISRole         = "file-store"
  }
}

resource "azurerm_private_endpoint" "file_store_pe" {
  count              = var.fileserver_deployment_id == null ? 1 : 0

  name                = "${azurerm_storage_account.file_store[0].name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.file_store[0].id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.privatelink_file.id]
  }
}

resource "azurerm_storage_share" "fileserver" {
  count              = var.fileserver_deployment_id == null ? 1 : 0

  name               = "fileserver"
  storage_account_id = azurerm_storage_account.file_store[0].id
  enabled_protocol   = "NFS"
  quota              = var.fileserver_size
}

resource "azurerm_key_vault_secret" "aznfs_network_path" {
  count        = var.fileserver_deployment_id == null ? 1 : 0

  name         = "${var.deployment_id}-aznfs-network-path"
  value        = local.aznfs_network_path
  key_vault_id = var.key_vault_id

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}
