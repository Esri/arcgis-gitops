/**
 * # Terraform Module K8s-cluster
 *
 * The Terraform module provisions Azure Kubernetes Service (AKS) cluster
 * that meets [ArcGIS Enterprise on Kubernetes system requirements](https://enterprise-k8s.arcgis.com/en/latest/deploy/deploy-a-cluster-in-azure-kubernetes-service.htm).
 *
 * ![Azure Kubernetes Service (AKS) cluster](k8s-cluster.png "Azure Kubernetes Service (AKS) cluster")
 *
 * The module creates a resource group with the following Azure resouces: 
 *
 * * AKS cluster with default node pool in the private subnet 1 and ingress controller in App Gateway subnet 1.
 * * Container registry with private endpoint in isolated subnet 1, private DNS zone, and cache rules to pull images from Docker Hub container registry.
 * * Monitoring subsyatem that include Azure Monitor workspace and Azure Managed Grafana instances.
 *
 * Once the AKS cluster is available, the module creates storage classes for Azure Disk CSI driver.
 *
 * ## Requirements
 *
 * The subnets and virtual network Ids are retrieved from Azure Key Vault secrets. The key vault, subnets, and other
 * network infrastructure resources must be created by the [infrastructure-core](../infrastructure-core) module.
 * 
 * On the machine where Terraform is executed:
 *
 * * Azure subscription Id must be specified by ARM_SUBSCRIPTION_ID environment variable.
 * * Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID, and ARM_CLIENT_SECRET environment variables.
 * * Azure CLI and kubectl must be installed.
 */

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

terraform {
  backend "azurerm" {
    key = "arcgis-enterprise/azure/k8s-cluster.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.1"
    }
  }
}

provider "azurerm" {
  # resource_provider_registrations = "none"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Retrieve Id of Application Gateway subnet 1 from Azure Key Vault secret
data "azurerm_key_vault_secret" "app_gateway_subnet_1" {
  name         = "app-gateway-subnet-1"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

# Retrieve Id of private subnet 1 from Azure Key Vault secret
data "azurerm_key_vault_secret" "private_subnet_1" {
  name         = "private-subnet-1"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

# Retrieve Id of internal subnet 1 from Azure Key Vault secret
data "azurerm_key_vault_secret" "internal_subnet_1" {
  name         = "internal-subnet-1"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

data "azurerm_key_vault_secret" "vnet_id" {
  name         = "vnet-id"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

data "azurerm_key_vault" "site_vault" {
  name                = var.site_id
  resource_group_name = "${var.site_id}-infrastructure-core"
}

resource "azurerm_resource_provider_registration" "microsoft_monitor" {
  name = "Microsoft.Monitor"
}

resource "azurerm_resource_provider_registration" "microsoft_dashboard" {
  name = "Microsoft.Dashboard"
}

# Create a resource group
resource "azurerm_resource_group" "cluster_rg" {
  name     = "${var.site_id}-k8s-cluster"
  location = var.azure_region

  depends_on = [
    azurerm_resource_provider_registration.microsoft_monitor,
    azurerm_resource_provider_registration.microsoft_dashboard
  ]
}

# Create an AKS cluster
resource "azurerm_kubernetes_cluster" "site_cluster" {
  name                  = var.site_id
  location              = azurerm_resource_group.cluster_rg.location
  resource_group_name   = azurerm_resource_group.cluster_rg.name
  dns_prefix            = var.site_id
  sku_tier              = "Standard"
  cost_analysis_enabled = true

  default_node_pool {
    name           = var.default_node_pool.name
    node_count     = var.default_node_pool.node_count
    vm_size        = var.default_node_pool.vm_size
    vnet_subnet_id = data.azurerm_key_vault_secret.private_subnet_1.value
    temporary_name_for_rotation = "temporary"
  }

  ingress_application_gateway {
    subnet_id = data.azurerm_key_vault_secret.app_gateway_subnet_1.value
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
    annotations_allowed = true
    labels_allowed      = true
  }

  # network_profile {
  #   network_plugin    = "azure"
  #   load_balancer_sku = "standard"
  # }

  # oms_agent {
  #   log_analytics_workspace_id      = azurerm_log_analytics_workspace.cluster_log_analytics.id
  #   msi_auth_for_monitoring_enabled = true
  # }

  tags = {
    ArcGISSiteId = var.site_id
  }
}

# Update kubeconfig to access the AKS cluster
resource "null_resource" "update_kubeconfig" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID"
  }

  provisioner "local-exec" {
    command = "az account set --subscription $ARM_SUBSCRIPTION_ID"
  }

  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.cluster_rg.name} --name ${azurerm_kubernetes_cluster.site_cluster.name} --overwrite-existing"
  }

  depends_on = [
    azurerm_kubernetes_cluster.site_cluster
  ]
}

# Create a storage classes 
resource "null_resource" "storage_class" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/sc_reclaim_delete.yaml --force"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/sc_reclaim_retain.yaml --force"
  }

  depends_on = [
    null_resource.update_kubeconfig
  ]
}

# Create a container registry 

resource "random_id" "container_registry_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new site id
    site_id = var.site_id
  }

  byte_length = 8
}

resource "azurerm_container_registry" "cluster_acr" {
  # ACR name must be unique and contain only alphanumeric characters
  name                          = "${replace(var.site_id, "-", "")}${random_id.container_registry_suffix.hex}"
  resource_group_name           = azurerm_resource_group.cluster_rg.name
  location                      = azurerm_resource_group.cluster_rg.location
  public_network_access_enabled = true
  sku                           = "Premium"

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_key_vault_secret" "cr_user" {
  name         = "cr-user"
  value        = var.container_registry_user
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

resource "azurerm_key_vault_secret" "cr_password" {
  name         = "cr-password"
  value        = var.container_registry_password
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

# Unfortunatelly, azurerm provider does not support creating container registry credential sets.
# See https://github.com/hashicorp/terraform-provider-azurerm/issues/26539
# Use Azure CLI to create credential set and grant its principal access the Key Vault secrets.
resource "null_resource" "credential_set" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
    credential=$(az acr credential-set create -r ${azurerm_container_registry.cluster_acr.name} -n pullthroughcache -l ${var.container_registry_url} -u ${data.azurerm_key_vault.site_vault.vault_uri}secrets/cr-user -p ${data.azurerm_key_vault.site_vault.vault_uri}secrets/cr-password)
    principal=$(echo $credential | jq -r '.identity.principalId')
    az keyvault set-policy --name ${data.azurerm_key_vault.site_vault.name} --object-id $principal --secret-permissions get
    EOT
  }
}

resource "azurerm_container_registry_cache_rule" "pull_through_cache" {
  name                  = "pullthroughcache"
  container_registry_id = azurerm_container_registry.cluster_acr.id
  target_repo           = "docker-hub/*"
  source_repo           = "${var.container_registry_url}/*"
  credential_set_id     = "${azurerm_container_registry.cluster_acr.id}/credentialSets/pullthroughcache"
  depends_on = [
    null_resource.credential_set
  ]
}

# Assign AcrPull role to the AKS cluster identity
resource "azurerm_role_assignment" "acr" {
  principal_id                     = azurerm_kubernetes_cluster.site_cluster.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.cluster_acr.id
  skip_service_principal_aad_check = true
}

# Create azure private endpoint for the container registry

resource "azurerm_private_dns_zone" "acr_private_dns_zone" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.cluster_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr_private_dns_zone_virtual_network_link" {
  name                  = "acr-private-dns-zone-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.acr_private_dns_zone.name
  resource_group_name   = azurerm_resource_group.cluster_rg.name
  virtual_network_id    = data.azurerm_key_vault_secret.vnet_id.value
}

resource "azurerm_private_endpoint" "acr_private_endpoint" {
  name                = "${azurerm_container_registry.cluster_acr.name}-private-endpoint"
  resource_group_name = azurerm_resource_group.cluster_rg.name
  location            = azurerm_resource_group.cluster_rg.location
  subnet_id           = data.azurerm_key_vault_secret.internal_subnet_1.value

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
