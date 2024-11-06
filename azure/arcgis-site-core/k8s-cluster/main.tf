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
 * * AKS cluster with default node pool in the private subnet 1 
 * * ALB Controller and Application Gateway for Containers associated with app gateway subnet 1.
 * * Container registry with private endpoint in internal subnet 1, private DNS zone, and cache rules to pull images from Docker Hub container registry.
 * * Monitoring subsystem that include Azure Monitor workspace and Azure Managed Grafana instances.
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
 * * Azure CLI, Helm and kubectl must be installed.
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
      version = "~> 4.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  backend_address_pool_name      = "${var.site_id}-beap"
  frontend_port_name             = "${var.site_id}-feport"
  frontend_ip_configuration_name = "${var.site_id}-feip"
  http_setting_name              = "${var.site_id}-be-htst"
  listener_name                  = "${var.site_id}-httplstn"
  request_routing_rule_name      = "${var.site_id}-rqrt"
  redirect_configuration_name    = "${var.site_id}-rdrcfg"
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

resource "azurerm_resource_provider_registration" "microsoft_monitor" {
  name = "Microsoft.Monitor"
}

resource "azurerm_resource_provider_registration" "microsoft_dashboard" {
  name = "Microsoft.Dashboard"
}

resource "azurerm_resource_provider_registration" "microsoft_network_function" {
  name = "Microsoft.NetworkFunction"
}

resource "azurerm_resource_provider_registration" "microsoft_service_networking" {
  name = "Microsoft.ServiceNetworking"
}

# Create a resource group
resource "azurerm_resource_group" "cluster_rg" {
  name     = "${var.site_id}-k8s-cluster"
  location = var.azure_region

  depends_on = [
    azurerm_resource_provider_registration.microsoft_monitor,
    azurerm_resource_provider_registration.microsoft_dashboard,
    azurerm_resource_provider_registration.microsoft_network_function,
    azurerm_resource_provider_registration.microsoft_service_networking
  ]
}

# Create an AKS cluster
resource "azurerm_kubernetes_cluster" "site_cluster" {
  name                      = var.site_id
  location                  = azurerm_resource_group.cluster_rg.location
  resource_group_name       = azurerm_resource_group.cluster_rg.name
  dns_prefix                = var.site_id
  sku_tier                  = "Standard"
  cost_analysis_enabled     = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                        = var.default_node_pool.name
    node_count                  = var.default_node_pool.node_count
    vm_size                     = var.default_node_pool.vm_size
    vnet_subnet_id              = var.subnet_id != null ? var.subnet_id : module.site_core_info.private_subnets[0]
    temporary_name_for_rotation = "temporary"
  }

  identity {
    type = "SystemAssigned"
  }

  monitor_metrics {
    annotations_allowed = true
    labels_allowed      = true
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = {
    ArcGISSiteId = var.site_id
  }
}

resource "azurerm_key_vault_secret" "aks_identity_client_id" {
  name         = "aks-identity-client-id"
  value        = azurerm_kubernetes_cluster.site_cluster.kubelet_identity[0].client_id
  key_vault_id = module.site_core_info.vault_id
}

resource "azurerm_key_vault_secret" "aks_identity_principal_id" {
  name         = "aks-identity-principal-id"
  value        = azurerm_kubernetes_cluster.site_cluster.kubelet_identity[0].object_id
  key_vault_id = module.site_core_info.vault_id
}

# Assign Storage Blob Data Contributor role to the AKS cluster identity
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  principal_id                     = azurerm_kubernetes_cluster.site_cluster.kubelet_identity[0].object_id
  role_definition_name             = "Storage Blob Data Contributor"
  scope                            = module.site_core_info.storage_account_id
  skip_service_principal_aad_check = true
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

module "container_registry" {
  source                      = "./modules/container-registry"
  azure_region                = var.azure_region
  site_id                     = var.site_id
  resource_group_name         = azurerm_resource_group.cluster_rg.name
  container_registry_url      = var.container_registry_url
  container_registry_user     = var.container_registry_user
  container_registry_password = var.container_registry_password
  principal_id                = azurerm_kubernetes_cluster.site_cluster.kubelet_identity[0].object_id
  subnet_id                   = module.site_core_info.internal_subnets[0]
  vnet_id                     = module.site_core_info.vnet_id

  depends_on = [
    azurerm_kubernetes_cluster.site_cluster
  ]
}

# Create ALB Controller and Application Gateway for Containers
module "alb_controller" {
  source              = "./modules/alb-controller"
  azure_region        = var.azure_region
  resource_group_name = azurerm_resource_group.cluster_rg.name
  cluster_name        = azurerm_kubernetes_cluster.site_cluster.name
  alb_subnet_id       = module.site_core_info.app_gateway_subnets[0]

  depends_on = [
    azurerm_kubernetes_cluster.site_cluster
  ]
}

resource "azurerm_key_vault_secret" "alb_id" {
  name         = "alb-id"
  value        = module.alb_controller.alb_id
  key_vault_id = module.site_core_info.vault_id
}

module "monitoring" {
  source              = "./modules/monitoring"
  azure_region        = var.azure_region
  resource_group_name = azurerm_resource_group.cluster_rg.name
  cluster_name        = azurerm_kubernetes_cluster.site_cluster.name
  site_id             = var.site_id

  depends_on = [
    azurerm_kubernetes_cluster.site_cluster
  ]
}
