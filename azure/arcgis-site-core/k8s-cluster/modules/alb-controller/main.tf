/**
 * # Terraform module alb-controller
 * 
 * The module deploys Application Gateway for Containers ALB Controller to AKS cluster:
 *
 * 1. Creates a user managed identity for ALB controller and federates the identity as Workload Identity to use in the AKS cluster.
 * 2. Assigns required roles to the identity.
 * 2. Installs ALB Controller using Helm.
 * 3. Creates an Application Gateway for Containers and associates it with a subnet.
 *
 * See: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller
 *
 * ## Requirements
 * 
 * Helm must be installed on the machine where terraform is executed.
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

data "azurerm_resource_group" "cluster_rg" {
  name = var.resource_group_name
}

data "azurerm_kubernetes_cluster" "site_cluster" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

# Create a user-assigned identity for the ALB Controller
resource "azurerm_user_assigned_identity" "azure_alb_identity" {
  location            = var.azure_region
  name                = "azure-alb-identity"
  resource_group_name = var.resource_group_name
}

# Wait for 60 seconds to allow for replication of the identity...
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"

  depends_on = [
    azurerm_user_assigned_identity.azure_alb_identity
  ]
}

# Apply Reader role to the AKS managed cluster resource group for the newly provisioned identity.
resource "azurerm_role_assignment" "aks_cluster_reader" {
  principal_id                     = azurerm_user_assigned_identity.azure_alb_identity.principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_name             = "Reader"
  # In ALB Controller 1.2.3 the scope had to be the node resource group of the AKS cluster.
  # scope                            = data.azurerm_kubernetes_cluster.site_cluster.node_resource_group_id
  scope                            = data.azurerm_resource_group.cluster_rg.id
  skip_service_principal_aad_check = true

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

# Delegate AppGw for Containers Configuration Manager role to the cluster resource group.
resource "azurerm_role_assignment" "appgw_configuration_manager" {
  principal_id                     = azurerm_user_assigned_identity.azure_alb_identity.principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_name             = "AppGw for Containers Configuration Manager"
  # scope                            = data.azurerm_kubernetes_cluster.site_cluster.node_resource_group_id
  scope                            = data.azurerm_resource_group.cluster_rg.id
  skip_service_principal_aad_check = true

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

# Delegate Network Contributor permission for join to association subnet
resource "azurerm_role_assignment" "network_contributor" {
  principal_id                     = azurerm_user_assigned_identity.azure_alb_identity.principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_name             = "Network Contributor"
  scope                            = var.alb_subnet_id
  skip_service_principal_aad_check = true

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

# Set up federation with AKS OIDC issuer
resource "azurerm_federated_identity_credential" "azure_alb_identity" {
  name                = "azure-alb-identity"
  parent_id           = azurerm_user_assigned_identity.azure_alb_identity.id
  audience            = [
    "api://AzureADTokenExchange"
  ]
  resource_group_name = var.resource_group_name
  issuer              = data.azurerm_kubernetes_cluster.site_cluster.oidc_issuer_url
  subject             = "system:serviceaccount:azure-alb-system:alb-controller-sa"

  depends_on = [
    azurerm_role_assignment.aks_cluster_reader,
    azurerm_role_assignment.appgw_configuration_manager,
    azurerm_role_assignment.network_contributor
  ]
}

# Install ALB Controller using Helm
resource "null_resource" "helm_install" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "helm upgrade --install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller --version ${var.controller_version} --set albController.namespace=azure-alb-system --set albController.podIdentity.clientID=${azurerm_user_assigned_identity.azure_alb_identity.client_id}"
  }

  depends_on = [
    azurerm_federated_identity_credential.azure_alb_identity
  ]
}

# Create an Application Gateway for Containers
resource "azurerm_application_load_balancer" "alb" {
  name                = var.cluster_name
  location            = var.azure_region
  resource_group_name = var.resource_group_name
}

# Associate the Application Gateway with app-gateway-subnet-1 subnet
resource "azurerm_application_load_balancer_subnet_association" "alb" {
  name                         = var.cluster_name
  application_load_balancer_id = azurerm_application_load_balancer.alb.id
  subnet_id                    = var.alb_subnet_id
}
