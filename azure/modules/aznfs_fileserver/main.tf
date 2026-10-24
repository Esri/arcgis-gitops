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

terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.6"
    }
  }
}

data "azurerm_private_dns_zone" "privatelink_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = "${var.enterprise_id}-infrastructure-core"
}

data "azurerm_key_vault_secret" "aznfs_network_path" {
  count = var.fileserver_deployment_id != null ? 1 : 0

  name         = "${var.fileserver_deployment_id}-aznfs-network-path"
  key_vault_id = var.key_vault_id
}

locals {
  fileserver_share_name = var.fileserver_billing_model_version == "V2" ? one(azapi_resource.fileserver_v2[*].name) : one(azurerm_storage_share.fileserver[*].name)
  aznfs_network_path    = var.fileserver_deployment_id != null ? data.azurerm_key_vault_secret.aznfs_network_path[0].value : "${azurerm_storage_account.file_store[0].name}.file.core.windows.net:/${azurerm_storage_account.file_store[0].name}/${local.fileserver_share_name}"
}

# Storage Account with NFS File Share for fileserver
resource "azurerm_storage_account" "file_store" {
  count = var.fileserver_deployment_id == null ? 1 : 0

  name                = "nfs${var.unique_name_suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier                      = "Premium"
  account_kind                      = "FileStorage"
  account_replication_type          = var.storage_replication_type
  provisioned_billing_model_version = var.fileserver_billing_model_version == "V2" ? "V2" : null

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
  count = var.fileserver_deployment_id == null ? 1 : 0

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
  count = var.fileserver_deployment_id == null && var.fileserver_billing_model_version == "V1" ? 1 : 0

  name               = "fileserver"
  storage_account_id = azurerm_storage_account.file_store[0].id
  enabled_protocol   = "NFS"
  quota              = var.fileserver_size
}

resource "azapi_resource" "fileserver_v2" {
  count = var.fileserver_deployment_id == null && var.fileserver_billing_model_version == "V2" ? 1 : 0

  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2025-06-01"
  name      = "fileserver"
  parent_id = "${azurerm_storage_account.file_store[0].id}/fileServices/default"
  body = {
    properties = {
      enabledProtocols          = "NFS"
      shareQuota                = var.fileserver_size
      provisionedIops           = var.fileserver_iops
      provisionedBandwidthMibps = var.fileserver_throughput
    }
  }
}

resource "azurerm_key_vault_secret" "aznfs_network_path" {
  count = var.fileserver_deployment_id == null ? 1 : 0

  name         = "${var.deployment_id}-aznfs-network-path"
  value        = local.aznfs_network_path
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_storage_share.fileserver, azapi_resource.fileserver_v2]

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}
