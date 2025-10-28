/**
 * # Ingress Terraform Module
 *
 * This module deploys an Azure Application Gateway for ArcGIS Enterprise site.
 *
 * ![ArcGIS Enterprise site ingress](arcgis-enterprise-ingress-azure.png "ArcGIS Enterprise site ingress")
 *
 * The Application Gateway is deployed into subnet specified by the "subnet_id" variable or, 
 * if the variable is not set "app-gateway-subnet-2" subnet of the site's VNet.
 *
 * The Application Gateway is configured with both public and private frontend IP configurations.
 * The public frontend configuration is assigned a public IP address, while the
 * private frontend configuration is assigned a static private IP address specified by 
 * the "ingress_private_ip" variable.
 *
 * The module creates a Private DNS Zone for the deployment's FQDN and links it to the
 * virtual network, allowing internal resolution of the FQDN to the Application Gateway's
 * private IP address
 *
 * The Application Gateway's listeners, backend pools, health probes, and routing rules are
 * dynamically configured from the settings defined by the "routing_rules" variable. 
 * By default the routing rules are set to route traffic to ports 443, 6443, and 7443 of 
 * "enterprise-base" backend pool.
 *
 * All the HTTPS listeners use the SSL certificate stored in the site's Key Vault. The certificate's
 * secret ID must be specified by "ssl_certificate_secret_id" variable.
 *
 * Requests to port 80 on both the public and private frontend IPs are redirected to port 443.
 *
 * The Application Gateway's monitoring subsystem consists of:
 *
 * * A Log Analytics workspace "{var.site_id}-{var.deployment_id}" that collects the access logs.
 * * An Azure Monitor dashboard "{var.site_id}-{var.deployment_id}" that visualizes key metrics of the Application Gateway.
 *
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 *
 * | Key Vault secret name | Description |
 * |--------------------|-------------|
 * | subnets | VNet subnets IDs |
 * | vnet-id | VNet ID |
 * | storage-account-key | Site's storage account key |
 * | storage-account-name | Site's storage account name |
 * | vm-identity-id | VM identity ID |
 *
 * ### Secrets Written by the Module
 *
 * | Secret Name | Description |
 * |-------------|-------------|
 * | ${var.deployment_id}-deployment-fqdn | Deployment's FQDN |
 * | ${var.deployment_id}-backend-address-pools | JSON-encoded map of backend address pool names to their IDs |
 */

# Copyright 2025 Esri
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
      version = "~> 4.46"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
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

data "azurerm_key_vault_secret" "vm_identity_id" {
  name         = "vm-identity-id"
  key_vault_id = module.site_core_info.vault_id
}

locals {
  app_gateway_subnet_id = var.subnet_id == null ? element(module.site_core_info.app_gateway_subnets, 1) : var.subnet_id

  # Get a distinct list of backend address pools from the routing rules
  pools = distinct(flatten([
    for routing in var.routing_rules : [
        for rule in routing.rules : rule.pool
    ]
  ]))

  # Flatten the list of rules to use in dynamic blocks
  all_backend_http_settings = flatten([
    for routing in var.routing_rules : [
      for rule in routing.rules : 
      {
        backend_port = routing.backend_port
        protocol     = routing.protocol
        name         = rule.name
        pool         = rule.pool
        probe        = rule.probe
        paths        = rule.paths
      }
    ]
  ])

  # Create a map of backend address pool names to their IDs
  backend_address_pools = {
    for pool in azurerm_application_gateway.ingress.backend_address_pool : pool.name => pool.id
  }
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

resource "azurerm_resource_group" "deployment_rg" {
  name     = "${var.site_id}-${var.deployment_id}-rg"
  location = var.azure_region
}

resource "azurerm_public_ip" "ingress" {
  name                = "${var.site_id}-${var.deployment_id}-pip"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.zones

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }

  # Terraform tries and fails to update zones even when there are no changes to the zones variable.
  lifecycle {
    ignore_changes = [
      zones
    ]
  }
}

resource "azurerm_application_gateway" "ingress" {
  name                = "${var.site_id}-${var.deployment_id}"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location
  zones               = var.zones

  sku {
    name = var.app_gateway_sku
    tier = var.app_gateway_sku
  }

  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_key_vault_secret.vm_identity_id.value
    ]
  }

  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = local.app_gateway_subnet_id
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.ingress.id
  }

  frontend_ip_configuration {
    name = "private-frontend"
    # Application Gateway with SKU tier Standard_v2 can only use PrivateIPAddress 
    # with IpAllocationMethod as Static.
    private_ip_address_allocation = "Static"
    private_ip_address            = var.ingress_private_ip
    subnet_id                     = local.app_gateway_subnet_id
  }

  # Redirect HTTP (port 80) to HTTPS (port 443)
  frontend_port {
    name = "80"
    port = 80
  }

  http_listener {
    name                           = "public-80"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "80"
    protocol                       = "Http"
  }

  http_listener {
    name                           = "private-80"
    frontend_ip_configuration_name = "private-frontend"
    frontend_port_name             = "80"
    protocol                       = "Http"
  }

  redirect_configuration {
    name                 = "public-http-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "public-443"
    include_path         = true
    include_query_string = true
  }

  redirect_configuration {
    name                 = "private-http-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "private-443"
    include_path         = true
    include_query_string = true
  }

  request_routing_rule {
    name                        = "public-http-redirect"
    priority                    = 1
    rule_type                   = "Basic"
    http_listener_name          = "public-80"
    redirect_configuration_name = "public-http-redirect"
  }

  request_routing_rule {
    name                        = "private-http-redirect"
    priority                    = 2
    rule_type                   = "Basic"
    http_listener_name          = "private-80"
    redirect_configuration_name = "private-http-redirect"
  }
  
  # Create frontend ports for each listener defined by "listeners" variable.
  dynamic "frontend_port" {
    for_each = var.routing_rules

    content {
      name = frontend_port.value.frontend_port
      port = frontend_port.value.frontend_port
    }
  }

  # Create both public and private listeners for each listener defined by "listeners" variable.
  # This allows the Application Gateway to accept traffic on both its public and private IPs
  dynamic "http_listener" {
    for_each = var.routing_rules

    content {
      name                           = "public-${http_listener.value.frontend_port}"
      frontend_ip_configuration_name = "public-frontend"
      frontend_port_name             = http_listener.value.frontend_port
      protocol                       = http_listener.value.protocol
      ssl_certificate_name           = "cert"
    }
  }

  dynamic "http_listener" {
    for_each = var.routing_rules

    content {
      name                           = "private-${http_listener.value.frontend_port}"
      frontend_ip_configuration_name = "private-frontend"
      frontend_port_name             = http_listener.value.frontend_port
      protocol                       = http_listener.value.protocol
      ssl_certificate_name           = "cert"
    }
  }

  dynamic "backend_address_pool" {
    for_each = local.pools

    content {
      name = backend_address_pool.value
    }
  }

  dynamic "backend_http_settings" {
    for_each = local.all_backend_http_settings

    content {
      name                  = backend_http_settings.value.name
      cookie_based_affinity = "Disabled"
      port                  = backend_http_settings.value.backend_port
      protocol              = backend_http_settings.value.protocol
      request_timeout       = var.request_timeout
      probe_name            = backend_http_settings.value.name
    }
  }

  dynamic "probe" {
    for_each = local.all_backend_http_settings

    content {
      name                = probe.value.name
      protocol            = "Https"
      host                = var.deployment_fqdn
      path                = probe.value.probe
      interval            = 60
      timeout             = 30
      unhealthy_threshold = 3
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.routing_rules

    content {
      name               = "public-${request_routing_rule.value.name}"
      priority           = request_routing_rule.value.priority
      rule_type          = "PathBasedRouting"
      url_path_map_name  = request_routing_rule.value.name
      http_listener_name = "public-${request_routing_rule.value.frontend_port}"
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.routing_rules

    content {
      name               = "private-${request_routing_rule.value.name}"
      priority           = 100 + request_routing_rule.value.priority
      rule_type          = "PathBasedRouting"
      url_path_map_name  = request_routing_rule.value.name
      http_listener_name = "private-${request_routing_rule.value.frontend_port}"
    }
  }

  dynamic "url_path_map" {
    for_each = var.routing_rules

    content {
      name                               = url_path_map.value.name
      default_backend_address_pool_name  = url_path_map.value.rules[0].pool
      default_backend_http_settings_name = url_path_map.value.rules[0].name

      dynamic "path_rule" {
        for_each = url_path_map.value.rules

        content {
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
          backend_address_pool_name  = path_rule.value.pool
          backend_http_settings_name = path_rule.value.name
        }
      }
    }
  }

  ssl_certificate {
    name                = "cert"
    key_vault_secret_id = var.ssl_certificate_secret_id
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = var.ssl_policy
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "deployment_fqdn" {
  name                = var.deployment_fqdn
  resource_group_name = azurerm_resource_group.deployment_rg.name

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "deployment-fqdn"
  resource_group_name   = azurerm_resource_group.deployment_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.deployment_fqdn.name
  virtual_network_id    = module.site_core_info.vnet_id
}

# Create a record in the private hosted zone that points the deployment's FQDN 
# to the Application Gateway's frontend private IP.
resource "azurerm_private_dns_a_record" "deployment_fqdn" {
  name                = "@" # Use "@" to denote the root of the DNS zone
  zone_name           = azurerm_private_dns_zone.deployment_fqdn.name
  resource_group_name = azurerm_resource_group.deployment_rg.name
  ttl                 = 300
  records = [
    azurerm_application_gateway.ingress.frontend_ip_configuration[1].private_ip_address
  ]
}

# Store the deployment FQDN and web contexts in Key Vault
resource "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  value        = var.deployment_fqdn
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Store the deployment FQDN and web contexts in Key Vault
resource "azurerm_key_vault_secret" "backend_address_pools" {
  name         = "${var.deployment_id}-backend-address-pools"
  value        = jsonencode(local.backend_address_pools)
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}
