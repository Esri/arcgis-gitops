/**
 * # Terraform module infrastructure-core
 *
 * Terraform module creates networking and storage Azure resources shared across
 * multiple deployments of an ArcGIS Enterprise site.
 * 
 * ![Core Infrastructure Resources](infrastructure-core.png "Core Infrastructure Resources")
 *
 * The module creates a virtual network with app gateway, private and internal subnets. 
 * The app gateway and private subnets are routed to a NAT Gateway to allow outbound access to the Internet.
 * Internal subnets allow access only to specific service endpoints.
 * For private and internal subnets the module creates network security groups with default rules.
 *
 * Optionally, the module creates and configures an Azure Bastion host in a dedicated 
 * AzureBastionSubnet subnet to allow secure RDP/SSH connections to virtual machines of the site.
 *
 * The module also creates a storage account for the site with blob containers 
 * for repository, logs, and backups.
 * 
 * Attributes of the resources are stored as secrets in the Azure Key Vault created by the module.
 *
 * | Key vault secret name | Description |
 * | --- | --- |
 * | vnet-id | ArcGIS Enterprise site VNet id |
 * | app-gateway-subnet-N | Id of Application Gateway subnet N |
 * | internal-subnet-N | Id of internal subnet N |
 * | private-subnet-N | Id of private subnet N |
 * | storage-account-name | Storage account name |
 *
 * ## Requirements
 * 
 *  On the machine where Terraform is executed:
 *
 * * Azure subscription Id must be specified by ARM_SUBSCRIPTION_ID environment variable.
 * * Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID, and ARM_CLIENT_SECRET environment variables.
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

terraform {
  backend "azurerm" {
    key = "arcgis-enterprise/azure/infrastructure-core.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.16"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true
  features {
  }
}

data "azurerm_client_config" "current" {}

resource "random_id" "unique_name_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new site id
    site_id = var.site_id
  }

  byte_length = 8
}

resource "azurerm_resource_group" "site_rg" {
  name     = "${var.site_id}-infrastructure-core"
  location = var.azure_region
  timeouts {
    delete = "30m"
  }

  tags = {
    ArcGISSiteId = var.site_id
  }
}

# Key Vault of ArcGIS Enterprise site
resource "azurerm_key_vault" "site_vault" {
  name                       = "site${random_id.unique_name_suffix.hex}" # must be globally unique
  location                   = azurerm_resource_group.site_rg.location
  resource_group_name        = azurerm_resource_group.site_rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  purge_protection_enabled   = false
  rbac_authorization_enabled = true

  tags = {
    ArcGISSiteId = var.site_id
    ArcGISRole   = "site-vault"
  }
}

# VNet of ArcGIS Enterprise site

resource "azurerm_virtual_network" "site_vnet" {
  name                = var.site_id
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
  address_space       = [var.vnet_cidr_block]

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_key_vault_secret" "vnet" {
  name         = "vnet-id"
  value        = azurerm_virtual_network.site_vnet.id
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

# Create Private DNS Zones and link the to the Virtual network.

resource "azurerm_private_dns_zone" "internal" {
  name                = "${var.site_id}.internal"
  resource_group_name = azurerm_resource_group.site_rg.name

  tags = {
    ArcGISSiteId = var.site_id
  }
}

# Random String for unique naming
resource "random_string" "name" {
  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  name                  = "dns-vnet-link-${random_string.name.result}"
  resource_group_name   = azurerm_resource_group.site_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.internal.name
  virtual_network_id    = azurerm_virtual_network.site_vnet.id
}

# resource "azurerm_private_dns_zone" "dns" {
#   count               = length(var.private_dns_zones)
#   name                = var.private_dns_zones[count.index]
#   resource_group_name = azurerm_resource_group.site_rg.name

#   tags = {
#     ArcGISSiteId = var.site_id
#   }
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "dns" {
#   count                 = length(var.private_dns_zones)
#   name                  = azurerm_private_dns_zone.dns[count.index].name
#   resource_group_name   = azurerm_resource_group.site_rg.name
#   private_dns_zone_name = azurerm_private_dns_zone.dns[count.index].name
#   virtual_network_id    = azurerm_virtual_network.site_vnet.id
# }

# NAT Gateway

resource "azurerm_public_ip" "nat" {
  name                = "${var.site_id}-nat"
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_nat_gateway" "nat" {
  name                = var.site_id
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
  sku_name            = "Standard"

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

# Application Gateway subnets

# A dedicated subnet is required for the application gateway. 
# You can have multiple instances of a specific Application Gateway deployment in a subnet.
# You can also deploy other application gateways in the subnet. 
# But you can't deploy any other resource in the Application Gateway subnet.
# You can't mix v1 and v2 Application Gateway SKUs on the same subnet.

resource "azurerm_subnet" "app_gateway_subnets" {
  count                           = length(var.app_gateway_subnets)
  name                            = "app-gateway-subnet-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.site_rg.name
  virtual_network_name            = azurerm_virtual_network.site_vnet.name
  default_outbound_access_enabled = false

  # Repeat the delegation block for each delegation in the delegations list
  dynamic "delegation" {
    for_each = var.app_gateway_subnets[count.index].delegations
    content {
      name = delegation.value

      service_delegation {
        name = delegation.value
      }
    }
  }

  address_prefixes = [
    var.app_gateway_subnets[count.index].cidr_block
  ]
}

# resource "azurerm_network_security_group" "app_gateway_nsg" {
#   name                = "${var.site_id}-app-gateway"
#   location            = azurerm_resource_group.site_rg.location
#   resource_group_name = azurerm_resource_group.site_rg.name
# }

# resource "azurerm_subnet_network_security_group_association" "app_gateway_subnets" {
#   count                     = length(var.app_gateway_subnets_cidr_blocks)
#   subnet_id                 = azurerm_subnet.app_gateway_subnets[count.index].id
#   network_security_group_id = azurerm_network_security_group.app_gateway_nsg.id
# }

resource "azurerm_subnet_nat_gateway_association" "app_gateway" {
  count          = length(azurerm_subnet.app_gateway_subnets)
  subnet_id      = azurerm_subnet.app_gateway_subnets[count.index].id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

# Private subnets are routed to NAT Gateway

resource "azurerm_subnet" "private_subnets" {
  count                           = length(var.private_subnets_cidr_blocks)
  name                            = "private-subnet-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.site_rg.name
  virtual_network_name            = azurerm_virtual_network.site_vnet.name
  default_outbound_access_enabled = false
  address_prefixes = [
    var.private_subnets_cidr_blocks[count.index]
  ]
}

resource "azurerm_network_security_group" "private_nsg" {
  name                = "${var.site_id}-private"
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
}

resource "azurerm_subnet_network_security_group_association" "private_subnets" {
  count                     = length(azurerm_subnet.private_subnets)
  subnet_id                 = azurerm_subnet.private_subnets[count.index].id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}

resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = length(azurerm_subnet.private_subnets)
  subnet_id      = azurerm_subnet.private_subnets[count.index].id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

# Internal subnets are routed to service endpoints only

resource "azurerm_subnet" "internal_subnets" {
  count                           = length(var.internal_subnets_cidr_blocks)
  name                            = "internal-subnet-${count.index + 1}"
  resource_group_name             = azurerm_resource_group.site_rg.name
  virtual_network_name            = azurerm_virtual_network.site_vnet.name
  default_outbound_access_enabled = false
  address_prefixes = [
    var.internal_subnets_cidr_blocks[count.index]
  ]
  service_endpoints = var.service_endpoints
}

resource "azurerm_network_security_group" "internal_nsg" {
  name                = "${var.site_id}-internal"
  location            = azurerm_resource_group.site_rg.location
  resource_group_name = azurerm_resource_group.site_rg.name
}

resource "azurerm_subnet_network_security_group_association" "internal_subnets" {
  count                     = length(azurerm_subnet.internal_subnets)
  subnet_id                 = azurerm_subnet.internal_subnets[count.index].id
  network_security_group_id = azurerm_network_security_group.internal_nsg.id
}

resource "azurerm_key_vault_secret" "subnets" {
  name = "subnets"
  value = jsonencode({
    app_gateway = azurerm_subnet.app_gateway_subnets.*.id
    private     = azurerm_subnet.private_subnets.*.id
    internal    = azurerm_subnet.internal_subnets.*.id
  })
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

data "azurerm_platform_image" "images" {
  for_each  = var.images
  location  = azurerm_resource_group.site_rg.location
  publisher = each.value.publisher
  offer     = each.value.offer
  sku       = each.value.sku
  version   = each.value.version
}

resource "azurerm_key_vault_secret" "images" {
  for_each     = data.azurerm_platform_image.images
  name         = "vm-image-${each.key}"
  value        = each.value.id
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

resource "azurerm_user_assigned_identity" "vm_identity" {
  location            = var.azure_region
  name                = "vm-identity"
  resource_group_name = azurerm_resource_group.site_rg.name
}

resource "azurerm_key_vault_secret" "vm_identity_principal_id" {
  name         = "vm-identity-principal-id"
  value        = azurerm_user_assigned_identity.vm_identity.principal_id
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

resource "azurerm_key_vault_secret" "vm_identity_client_id" {
  name         = "vm-identity-client-id"
  value        = azurerm_user_assigned_identity.vm_identity.client_id
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

resource "azurerm_key_vault_secret" "vm_identity_id" {
  name         = "vm-identity-id"
  value        = azurerm_user_assigned_identity.vm_identity.id
  key_vault_id = azurerm_key_vault.site_vault.id

  depends_on = [
    time_sleep.key_vault_ready
  ]
}

resource "azurerm_role_assignment" "storage_account_vm_identity" {
  principal_id                     = azurerm_user_assigned_identity.vm_identity.principal_id
  role_definition_name             = "Storage Blob Data Owner"
  scope                            = azurerm_storage_account.site_storage.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "key_vault_current_user" {
  principal_id                     = data.azurerm_client_config.current.object_id
  role_definition_name             = "Key Vault Administrator"
  scope                            = azurerm_key_vault.site_vault.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "key_vault_vm_identity" {
  principal_id                     = azurerm_user_assigned_identity.vm_identity.principal_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.site_vault.id
  skip_service_principal_aad_check = true
}

resource "time_sleep" "key_vault_ready" {
  depends_on      = [azurerm_role_assignment.key_vault_current_user]
  create_duration = "90s"
}