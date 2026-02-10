/**
 * # Infrastructure Terraform Module for Base ArcGIS Enterprise on Windows
 *
 * This Terraform module provisions Azure resources required for a base ArcGIS Enterprise deployment on Windows.
 *
 * ![Base ArcGIS Enterprise on Windows / Infrastructure](arcgis-enterprise-base-windows-infrastructure.png "Base ArcGIS Enterprise on Windows / Infrastructure")
 *
 * ## Features
 *
 * - Launches one or two VMs (based on the "is_ha" variable) in the first private VNet subnet or a specified subnet.
 * - VM images are retrieved from Key Vault secrets named "vm-image-${var.site_id}-${var.deployment_id}-${vm_role}".
 *   These images must be built using the Packer template for ArcGIS Enterprise on Windows.
 * - Creates "A" records in the VNet's private hosted DNS zone, enabling permanent DNS names for the VMs.
 *   VMs can be addressed as primary.<deployment_id>.<site_id>.internal and standby.<deployment_id>.<site_id>.internal.
 *   > Note: VMs will be replaced if the module is re-applied after updating Key Vault secrets with new image builds.
 * - Provisions an Azure Storage Account with blob containers for portal content and object store.
 *   The storage account name is stored in the Key Vault secret "${var.deployment_id}-storage-account-name".
 * - If "is_ha" variable is true, provisions a Cosmos DB account and a Service Bus namespace for ArcGIS Server configuration store.
 * - Adds VM network interfaces to the "enterprise-base" backend address pool of the Application Gateway deployed by the ingress module.
 * - Creates an Azure Monitor dashboard for monitoring key VM metrics.
 * - Tags all resources with ArcGISSiteId and ArcGISDeploymentId for easy identification.
 *
 * ## Requirements
 *
 * Before running Terraform, configure Azure credentials using "az login" CLI command.
 *
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 * | Secret Name                                      | Description                                      |
 * |--------------------------------------------------|--------------------------------------------------|
 * | ${var.ingress_deployment_id}-backend-address-pools| Application Gateway backend address pools         |
 * | ${var.ingress_deployment_id}-deployment-fqdn     | Ingress deployment FQDN                          |
 * | storage-account-key                              | Storage account key                              |
 * | storage-account-name                             | Storage account name                             |
 * | subnets                                          | VNet subnet IDs                                  |
 * | vm-identity-id                                   | User-assigned VM identity object ID              |
 * | vm-identity-principal-id                         | User-assigned VM identity principal ID           |
 * | vm-image-${var.site_id}-${var.deployment_id}-primary | Primary VM image ID                         |
 * | vm-image-${var.site_id}-${var.deployment_id}-standby | Standby VM image ID                         |
 * | vnet-id                                          | VNet ID                                          |
 *
 * ### Secrets Written by the Module
 * | Secret Name                        | Description                        |
 * |------------------------------------|------------------------------------|
 * | ${var.deployment_id}-deployment-fqdn | Deployment's FQDN |
 * | ${var.deployment_id}-storage-account-name | Deployment's storage account name |
 */
 
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

terraform {
  backend "azurerm" {
    key = "terraform/arcgis/enterprise-base-windows/infrastructure.tfstate"
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

data "azurerm_key_vault_secret" "vm_image_ids" {
  count        = length(local.vm_roles)
  name         = "vm-image-${var.site_id}-${var.deployment_id}-${local.vm_roles[count.index]}"
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

locals {
  vm_roles  = var.is_ha ? ["primary", "standby"] : ["primary"]
  zones     = var.is_ha ? ["1", "2"] : ["1"]
  subnet_id = var.subnet_id != null ? var.subnet_id : element(module.site_core_info.private_subnets, 0)
  # app_gateway_subnet_id   = element(module.site_core_info.app_gateway_subnets, 1)
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

resource "azurerm_network_interface" "nics" {
  count               = length(local.vm_roles)
  name                = "${local.vm_roles[count.index]}-nic"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.deployment_rg.name

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = local.vm_roles[count.index]
  }
}

resource "azurerm_windows_virtual_machine" "vms" {
  count               = length(local.vm_roles)
  name                = local.vm_roles[count.index]
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location
  zone                = local.zones[count.index]
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  source_image_id = data.azurerm_key_vault_secret.vm_image_ids[count.index].value

  network_interface_ids = [
    azurerm_network_interface.nics[count.index].id
  ]

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
    ArcGISRole         = local.vm_roles[count.index]
  }
}

# Copy the ingress deployment FQDN from the ingress deployment Key Vault secret
resource "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  value        = data.azurerm_key_vault_secret.deployment_fqdn.value
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Create a record in the internal hosted zone for each VM.
# So the VMS can be addressed by their permanent DNS names like  
# primary.<deployment_id>.<site_id>.internal and
# standby.<deployment_id>.<site_id>.internal
resource "azurerm_private_dns_a_record" "fqdn" {
  count               = length(azurerm_network_interface.nics)
  name                = "${local.vm_roles[count.index]}.${var.deployment_id}"
  zone_name           = "${var.site_id}.internal"
  resource_group_name = "${var.site_id}-infrastructure-core"
  ttl                 = 300
  records = [
    azurerm_windows_virtual_machine.vms[count.index].private_ip_address
  ]
}

# Associate the NICs of the VMs with the backend address pool of the Application Gateway
resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "targets" {
  count                   = length(azurerm_network_interface.nics)
  network_interface_id    = azurerm_network_interface.nics[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = local.backend_address_pool_id
}

resource "random_id" "unique_name_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new site id
    site_id = var.site_id
  }

  byte_length = 8
}

resource "azurerm_storage_account" "deployment_storage" {
  name                     = "gis${random_id.unique_name_suffix.hex}"
  resource_group_name      = azurerm_resource_group.deployment_rg.name
  location                 = azurerm_resource_group.deployment_rg.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  # Public network access is enabled for the storage account because it is required
  # just to create the blob containers.
  public_network_access_enabled     = true
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Assign Storage Blob Data Owner role to the current user identity
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

# Assign Storage Blob Data Owner role to the VM identity
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

# Storage Containers for Portal content and Object Store
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

# Cosmos DB account for ArcGIS Enterprise
resource "azurerm_cosmosdb_account" "deployment_cosmosdb" {
  count               = var.is_ha ? 1 : 0
  name                = "gis${random_id.unique_name_suffix.hex}"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  # is_virtual_network_filter_enabled = true

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

resource "azurerm_cosmosdb_sql_database" "config_store" {
  count               = var.is_ha ? 1 : 0
  name                = "config-store"
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  account_name        = azurerm_cosmosdb_account.deployment_cosmosdb[0].name
  # throughput          = 400
}

# Assign Cosmos DB Operator role to the current user identity
resource "azurerm_role_assignment" "cosmosdb_owner" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Cosmos DB Operator"
  scope                            = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
  skip_service_principal_aad_check = true
}

# Assign Cosmos DB Operator role to the VM identity
resource "azurerm_role_assignment" "cosmosdb_vm_identity" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Cosmos DB Operator"
  scope                            = azurerm_cosmosdb_account.deployment_cosmosdb[0].id
  skip_service_principal_aad_check = true
}

# Assign Data Contributor role to the current user identity and VM identity for Cosmos DB SQL API
data "azurerm_cosmosdb_sql_role_definition" "data_contributor" {
  count               = var.is_ha ? 1 : 0
  account_name        = azurerm_cosmosdb_account.deployment_cosmosdb[0].name
  resource_group_name = azurerm_cosmosdb_account.deployment_cosmosdb[0].resource_group_name
  role_definition_id  = "00000000-0000-0000-0000-000000000002" # Built-in Data Contributor role ID
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
  count               = var.is_ha ? 1 : 0
  name                = "gis${random_id.unique_name_suffix.hex}"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  sku                 = "Premium"
  capacity            = 1
  premium_messaging_partitions = 1

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Assign Data Owner role to the current user identity
resource "azurerm_role_assignment" "servicebus_owner" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Azure Service Bus Data Owner"
  scope                            = azurerm_servicebus_namespace.deployment_servicebus[0].id
  skip_service_principal_aad_check = true
}

# Assign Data Owner role to the VM identity
resource "azurerm_role_assignment" "servicebus_vm_identity" {
  count                            = var.is_ha ? 1 : 0
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Azure Service Bus Data Owner"
  scope                            = azurerm_servicebus_namespace.deployment_servicebus[0].id
  skip_service_principal_aad_check = true
}
