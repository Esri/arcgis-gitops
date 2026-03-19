/**
 * # Infrastructure Terraform Module for Base ArcGIS Enterprise on Linux
 *
 * This Terraform module provisions Azure resources required for a base ArcGIS Enterprise deployment on Linux.
 *
 * ![Base ArcGIS Enterprise on Linux / Infrastructure](arcgis-enterprise-base-linux-infrastructure.png "Base ArcGIS Enterprise on Linux / Infrastructure")
 *
 * ## Features
 *
 * - Launches one or two Linux VMs (based on the "is_ha" variable) in the first private VNet subnet or a specified subnet.
 * - VM images are retrieved from Key Vault secrets named "${var.deployment_id}-vm-image-primary" and "${var.deployment_id}-vm-image-standby".
 *   These images must be built using the Packer template for ArcGIS Enterprise on Linux.
 * - Creates "A" records in the VNet's private DNS zone, enabling permanent DNS names for the VMs.
 *   VMs can be addressed as primary.<deployment_id>.<site_id>.internal and standby.<deployment_id>.<site_id>.internal.
 *   > Note: VMs will be replaced if the module is re-applied after updating Key Vault secrets with new image builds.
 * - Provisions an Azure Storage Account with blob containers for portal content and object store.
 *   The storage account name is stored in the Key Vault secret "${var.deployment_id}-storage-account-name".
 * - Provisions an NFS Azure Files storage account (file_store) with a "fileserver" NFS share mounted to the VMs.
 * - If "is_ha" variable is true, provisions a Cosmos DB account and a Service Bus namespace for ArcGIS Server configuration store.
 * - Adds VM network interfaces to the "enterprise-base" backend address pool of the Application Gateway deployed by the ingress module.
 * - Creates an Azure Monitor dashboard for monitoring key VM metrics.
 * - Tags all resources with ArcGISSiteId and ArcGISDeploymentId for easy identification.
 *
 * ## Requirements
 *
 * Before running Terraform, configure Azure credentials using "az login" command.
 *
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 *
 * | Secret Name                                      | Description |
 * |--------------------------------------------------|-------------|
 * | ${var.deployment_id}-os                          | Operating system ID |
 * | ${var.deployment_id}-portal-web-context          | Portal for ArcGIS web context |
 * | ${var.deployment_id}-vm-image-primary            | Primary VM image ID |
 * | ${var.deployment_id}-vm-image-standby            | Standby VM image ID |
 * | ${var.ingress_deployment_id}-backend-address-pools | Application Gateway backend address pools |
 * | ${var.ingress_deployment_id}-deployment-fqdn     | Ingress deployment FQDN |
 * | storage-account-key                              | Site storage account key |
 * | storage-account-name                             | Site storage account name |
 * | subnets                                          | VNet subnet IDs |
 * | vm-identity-id                                   | User-assigned VM identity resource ID |
 * | vm-identity-principal-id                         | User-assigned VM identity principal ID |
 * | vnet-id                                          | VNet ID |
 *
 * ### Secrets Written by the Module
 *
 * | Secret Name                               | Description |
 * |-------------------------------------------|-------------|
 * | ${var.deployment_id}-deployment-fqdn      | Deployment's FQDN |
 * | ${var.deployment_id}-deployment-url       | Portal for ArcGIS URL of the deployment |
 * | ${var.deployment_id}-storage-account-name | Deployment's storage account name |
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

terraform {
  backend "azurerm" {
    key = "terraform/arcgis/enterprise-base-linux/infrastructure.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_secret" "vm_identity_id" {
  name         = "vm-identity-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_identity_principal_id" {
  name         = "vm-identity-principal-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "primary_vm_image_id" {
  name         = "${var.deployment_id}-vm-image-primary"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "standby_vm_image_id" {
  name         = "${var.deployment_id}-vm-image-standby"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_image_os" {
  name         = "${var.deployment_id}-os"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "portal_web_context" {
  name         = "${var.deployment_id}-portal-web-context"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "backend_address_pools" {
  name         = "${var.ingress_deployment_id}-backend-address-pools"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.ingress_deployment_id}-deployment-fqdn"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_private_dns_zone" "privatelink_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

data "azurerm_private_dns_zone" "privatelink_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

data "azurerm_private_dns_zone" "cosmos_private_dns_zone" {
  count               = var.is_ha ? 1 : 0
  name                = "privatelink.documents.azure.com"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

data "azurerm_private_dns_zone" "servicebus_private_dns_zone" {
  count               = var.is_ha ? 1 : 0
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

locals {
  deployment_fqdn         = nonsensitive(data.azurerm_key_vault_secret.deployment_fqdn.value)
  portal_web_context      = nonsensitive(data.azurerm_key_vault_secret.portal_web_context.value)
  zones                   = var.is_ha ? ["1", "2"] : ["1"]
  subnet_id               = var.subnet_id != null ? var.subnet_id : element(module.site_core_info.private_subnets, 0)
  backend_address_pool_id = jsondecode(data.azurerm_key_vault_secret.backend_address_pools.value)["enterprise-base"]
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

resource "azurerm_resource_group" "deployment_rg" {
  name     = "${var.site_id}-${var.deployment_id}-rg"
  location = var.azure_region
}

resource "azurerm_network_interface" "primary" {
  name                = "primary-nic"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.deployment_rg.name

  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "primary"
  }
}

resource "azurerm_network_interface" "standby" {
  count               = var.is_ha ? 1 : 0
  name                = "standby-nic"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.deployment_rg.name

  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "standby"
  }
}

resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                = var.deployment_id
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name

  platform_fault_domain_count = 1
  zones                       = local.zones
}

resource "azurerm_linux_virtual_machine" "primary" {
  name                         = "primary"
  resource_group_name          = azurerm_resource_group.deployment_rg.name
  location                     = azurerm_resource_group.deployment_rg.location
  virtual_machine_scale_set_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  size = var.vm_size

  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = var.vm_admin_public_ssh_key_path != null

  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true

  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "ImageDefault"

  source_image_id = data.azurerm_key_vault_secret.primary_vm_image_id.value

  network_interface_ids = [
    azurerm_network_interface.primary.id
  ]

  dynamic "admin_ssh_key" {
    for_each = var.vm_admin_public_ssh_key_path != null ? [1] : []
    content {
      username   = var.vm_admin_username
      public_key = file(var.vm_admin_public_ssh_key_path)
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_key_vault_secret.vm_identity_id.value
    ]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "primary"
  }

  # Ignore changes to admin username, password, and zone to prevent VM replacement when these values are updated
  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password,
      zone
    ]
  }
}

resource "azurerm_linux_virtual_machine" "standby" {
  count                        = var.is_ha ? 1 : 0
  name                         = "standby"
  resource_group_name          = azurerm_resource_group.deployment_rg.name
  location                     = azurerm_resource_group.deployment_rg.location
  virtual_machine_scale_set_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  size = var.vm_size

  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = var.vm_admin_public_ssh_key_path != null

  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true

  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "ImageDefault"

  source_image_id = data.azurerm_key_vault_secret.standby_vm_image_id.value

  network_interface_ids = [
    azurerm_network_interface.standby[0].id
  ]

  dynamic "admin_ssh_key" {
    for_each = var.vm_admin_public_ssh_key_path != null ? [1] : []
    content {
      username   = var.vm_admin_username
      public_key = file(var.vm_admin_public_ssh_key_path)
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_key_vault_secret.vm_identity_id.value
    ]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "standby"
  }

  # Ignore changes to admin username, password, and zone to prevent VM replacement when these values are updated
  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password,
      zone
    ]
  }
}

resource "random_id" "unique_name_suffix" {
  keepers = {
    site_id       = var.site_id
    deployment_id = var.deployment_id
  }

  byte_length = 8
}

resource "azurerm_storage_account" "deployment_storage" {
  name                              = "gis${random_id.unique_name_suffix.hex}"
  resource_group_name               = azurerm_resource_group.deployment_rg.name
  location                          = azurerm_resource_group.deployment_rg.location
  account_tier                      = "Standard"
  account_kind                      = "StorageV2"
  account_replication_type          = var.storage_replication_type
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [local.subnet_id]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_private_endpoint" "blob_storage_pe" {
  name                = "blob-storage-pe"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.deployment_storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.privatelink_blob.id]
  }
}

resource "azurerm_role_assignment" "storage_blob_owner" {
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.deployment_storage.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "storage_table_owner" {
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Storage Table Data Contributor"
  scope                            = azurerm_storage_account.deployment_storage.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "storage_blob_vm_identity" {
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.deployment_storage.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "storage_table_vm_identity" {
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Storage Table Data Contributor"
  scope                            = azurerm_storage_account.deployment_storage.id
  skip_service_principal_aad_check = true
}

resource "azurerm_storage_container" "portal_content" {
  name                  = "portal-content"
  storage_account_id    = azurerm_storage_account.deployment_storage.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "object_store" {
  name                  = "object-store"
  storage_account_id    = azurerm_storage_account.deployment_storage.id
  container_access_type = "private"
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "${var.deployment_id}-storage-account-name"
  value        = azurerm_storage_account.deployment_storage.name
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Storage Account with NFS File Share for fileserver
resource "azurerm_storage_account" "file_store" {
  name                = "nfs${random_id.unique_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location

  account_tier             = "Premium"
  account_kind             = "FileStorage"
  account_replication_type = var.storage_replication_type

  https_traffic_only_enabled = false
  is_hns_enabled             = false

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [local.subnet_id]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "file-store"
  }
}

resource "azurerm_private_endpoint" "file_store_pe" {
  name                = "${azurerm_storage_account.file_store.name}-pe"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.file_store.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.privatelink_file.id]
  }
}

resource "azurerm_storage_share" "fileserver" {
  name               = "fileserver"
  storage_account_id = azurerm_storage_account.file_store.id
  enabled_protocol   = "NFS"
  quota              = var.fileserver_size
}

# Extend the root volume on the VMs.
module "lv_extend" {
  source        = "../../modules/lv_extend"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "standby"]
  os            = nonsensitive(data.azurerm_key_vault_secret.vm_image_os.value)

  depends_on = [
    azurerm_linux_virtual_machine.primary,
    azurerm_linux_virtual_machine.standby,
    azurerm_storage_share.fileserver,
    azurerm_private_endpoint.file_store_pe
  ]
}

# Mount the file share to the VMs.
module "aznfs_mount" {
  source        = "../../modules/aznfs_mount"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "standby"]
  storage_account_name = azurerm_storage_account.file_store.name
  file_share_name      = azurerm_storage_share.fileserver.name
  mount_point          = "/mnt/fileserver"

  depends_on = [
    module.lv_extend
  ]
}

# Cosmos DB account for ArcGIS Enterprise
resource "azurerm_cosmosdb_account" "deployment_cosmosdb" {
  count               = var.is_ha ? 1 : 0
  name                = "gis${random_id.unique_name_suffix.hex}"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Strong"
  }

  backup {
    type = "Continuous"
    tier = "Continuous30Days"
  }

  geo_location {
    location          = azurerm_resource_group.deployment_rg.location
    failover_priority = 0
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_private_endpoint" "cosmos_pe" {
  count               = var.is_ha ? 1 : 0
  name                = "cosmos-pe"
  location            = azurerm_cosmosdb_account.deployment_cosmosdb[0].location
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "psc-cosmos-sql"
    private_connection_resource_id = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.cosmos_private_dns_zone[0].id]
  }
}

resource "azurerm_cosmosdb_sql_database" "config_store" {
  count               = var.is_ha ? 1 : 0
  name                = "config-store"
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  account_name        = azurerm_cosmosdb_account.deployment_cosmosdb[0].name
}

resource "azurerm_role_assignment" "cosmosdb_owner" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Cosmos DB Operator"
  scope                            = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "cosmosdb_vm_identity" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Cosmos DB Operator"
  scope                            = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
  skip_service_principal_aad_check = true
}

data "azurerm_cosmosdb_sql_role_definition" "data_contributor" {
  count               = var.is_ha ? 1 : 0
  account_name        = azurerm_cosmosdb_account.deployment_cosmosdb[0].name
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  role_definition_id  = "00000000-0000-0000-0000-000000000002"
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_owner" {
  count               = var.is_ha ? 1 : 0
  account_name        = azurerm_cosmosdb_account.deployment_cosmosdb[0].name
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  principal_id        = data.azurerm_client_config.current.object_id
  role_definition_id  = data.azurerm_cosmosdb_sql_role_definition.data_contributor[0].id
  scope               = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
}

resource "azurerm_cosmosdb_sql_role_assignment" "cosmosdb_vm_identity" {
  count               = var.is_ha ? 1 : 0
  account_name        = azurerm_cosmosdb_account.deployment_cosmosdb[0].name
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  principal_id        = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_id  = data.azurerm_cosmosdb_sql_role_definition.data_contributor[0].id
  scope               = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
}

# Service Bus namespace for ArcGIS Server configuration store
resource "azurerm_servicebus_namespace" "deployment_servicebus" {
  count                        = var.is_ha ? 1 : 0
  name                         = "gis${random_id.unique_name_suffix.hex}"
  location                     = azurerm_resource_group.deployment_rg.location
  resource_group_name          = azurerm_resource_group.deployment_rg.name
  sku                          = "Premium"
  capacity                     = 1
  premium_messaging_partitions = 1

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_private_endpoint" "servicebus_pe" {
  count               = var.is_ha ? 1 : 0
  name                = "servicebus-pe"
  location            = azurerm_servicebus_namespace.deployment_servicebus[0].location
  resource_group_name = azurerm_servicebus_namespace.deployment_servicebus[0].resource_group_name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "psc-servicebus"
    private_connection_resource_id = azurerm_servicebus_namespace.deployment_servicebus[0].id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "sb-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.servicebus_private_dns_zone[0].id]
  }
}

resource "azurerm_role_assignment" "servicebus_owner" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Azure Service Bus Data Owner"
  scope                            = azurerm_servicebus_namespace.deployment_servicebus[0].id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "servicebus_vm_identity" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Azure Service Bus Data Owner"
  scope                            = azurerm_servicebus_namespace.deployment_servicebus[0].id
  skip_service_principal_aad_check = true
}

# Create DNS records for VMs
resource "azurerm_private_dns_a_record" "primary" {
  name                = "primary.${var.deployment_id}"
  zone_name           = "${var.site_id}.internal"
  resource_group_name = "${var.site_id}-infrastructure-core"
  ttl                 = 300
  records = [
    azurerm_linux_virtual_machine.primary.private_ip_address
  ]
}

resource "azurerm_private_dns_a_record" "standby" {
  count               = var.is_ha ? 1 : 0
  name                = "standby.${var.deployment_id}"
  zone_name           = "${var.site_id}.internal"
  resource_group_name = "${var.site_id}-infrastructure-core"
  ttl                 = 300
  records = [
    azurerm_linux_virtual_machine.standby[0].private_ip_address
  ]
}

# Associate the NICs of the VMs with the backend address pool of the Application Gateway
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "primary" {
  network_interface_id    = azurerm_network_interface.primary.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = local.backend_address_pool_id
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "standby" {
  count                   = var.is_ha ? 1 : 0
  network_interface_id    = azurerm_network_interface.standby[0].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = local.backend_address_pool_id
}

# Copy the ingress deployment FQDN from the ingress deployment Key Vault secret
resource "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  value        = local.deployment_fqdn
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_key_vault_secret" "deployment_url" {
  name         = "${var.deployment_id}-deployment-url"
  value        = "https://${local.deployment_fqdn}/${local.portal_web_context}"
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}
