/**
 * # Terraform module container-registry
 * 
 * The module creates and configures Azure Container Registry for AKS cluster:
 *
 * 1. Creates Azure Container Registry.
 * 2. Configures pull-through cache to pull images from Docker Hub.
 *    See https://learn.microsoft.com/en-us/azure/container-registry/container-registry-artifact-cache
 * 3. Assigns AcrPull role to the AKS cluster identity.
 * 4. Creates Azure Private Endpoint for the container registry.
 *    See https://learn.microsoft.com/en-us/azure/container-registry/container-registry-private-link
 *
 * ## Requirements
 * 
 * Azure CLI must be installed on the machine where terraform is executed.
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

module "site_core_info" {
  source  = "../../../../modules/site_core_info"
  site_id = var.site_id
}

resource "random_id" "container_registry_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new site id
    site_id = var.site_id
  }

  byte_length = 8
}

# Create Azure Container Registry
resource "azurerm_container_registry" "cluster_acr" {
  # ACR name must be unique and contain only alphanumeric characters
  name                          = "${replace(var.site_id, "-", "")}${random_id.container_registry_suffix.hex}"
  resource_group_name           = var.resource_group_name
  location                      = var.azure_region
  public_network_access_enabled = true
  sku                           = "Premium"

  tags = {
    ArcGISSiteId = var.site_id
  }
}

# Create Key Vault secrets for the ACR name
resource "azurerm_key_vault_secret" "acr_name" {
  name         = "acr-name"
  value        = azurerm_container_registry.cluster_acr.name
  key_vault_id = module.site_core_info.vault_id
}

# Create Key Vault secrets for the ACR login server
resource "azurerm_key_vault_secret" "acr_login_server" {
  name         = "acr-login-server"
  value        = azurerm_container_registry.cluster_acr.login_server
  key_vault_id = module.site_core_info.vault_id
}

resource "azurerm_key_vault_secret" "cr_user" {
  name         = "cr-user"
  value        = var.container_registry_user
  key_vault_id = module.site_core_info.vault_id
}

resource "azurerm_key_vault_secret" "cr_password" {
  name         = "cr-password"
  value        = var.container_registry_password
  key_vault_id = module.site_core_info.vault_id
}

# Create container registry credential set for the pull-through cache.
resource "azurerm_container_registry_credential_set" "credential_set" {
  name                  = "pullthroughcache"
  container_registry_id = azurerm_container_registry.cluster_acr.id
  login_server          = var.container_registry_url
  
  identity {
    type = "SystemAssigned"
  }
  
  authentication_credentials {
    username_secret_id = "${module.site_core_info.vault_uri}secrets/cr-user"
    password_secret_id = "${module.site_core_info.vault_uri}secrets/cr-password"
  }
}

# Allow the ACR pull-through cache principal access to the Key Vault secrets.
resource "azurerm_role_assignment" "pull_through_cache" {
  principal_id                     = azurerm_container_registry_credential_set.credential_set.identity[0].principal_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = module.site_core_info.vault_id
  skip_service_principal_aad_check = true
}

resource "azurerm_container_registry_cache_rule" "pull_through_cache" {
  name                  = "pullthroughcache"
  container_registry_id = azurerm_container_registry.cluster_acr.id
  target_repo           = "docker-hub/*"
  source_repo           = "${var.container_registry_url}/*"
  credential_set_id     = "${azurerm_container_registry.cluster_acr.id}/credentialSets/pullthroughcache"
  depends_on = [
    azurerm_container_registry_credential_set.credential_set
  ]
}

# Assign AcrPull role to the AKS cluster identity
resource "azurerm_role_assignment" "acr" {
  principal_id                     = var.principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.cluster_acr.id
  skip_service_principal_aad_check = true
}

# Create azure private endpoint for the container registry

resource "azurerm_private_dns_zone" "acr_private_dns_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_private_dns_zone_virtual_network_link" {
  name                  = "acr-private-dns-zone-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.acr_private_dns_zone.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.vnet_id
}

resource "azurerm_private_endpoint" "acr_private_endpoint" {
  name                = "${azurerm_container_registry.cluster_acr.name}-private-endpoint"
  resource_group_name = var.resource_group_name
  location            = var.azure_region
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_container_registry.cluster_acr.name}-service-connection"
    private_connection_resource_id = azurerm_container_registry.cluster_acr.id
    is_manual_connection           = false
    subresource_names = [
      "registry"
    ]
  }

  private_dns_zone_group {
    name = "${azurerm_container_registry.cluster_acr.name}-private-dns-zone-group"

    private_dns_zone_ids = [
      azurerm_private_dns_zone.acr_private_dns_zone.id
    ]
  }

  tags = {
    ArcGISSiteId = var.site_id
  }
}
