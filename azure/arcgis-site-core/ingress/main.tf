/**
 * # Ingress Terraform Module
 *
 * Provisions Azure Application Gateway ingress for an ArcGIS Enterprise site, including
 * public and private listeners, rule-driven backend routing, HTTP-to-HTTPS redirection,
 * and backend trust configuration. The module integrates with Key Vault for certificates
 * and secrets, creates deployment DNS records, and enables monitoring resources for
 * gateway health and diagnostics.
 *
 * ![ArcGIS Enterprise site ingress](arcgis-enterprise-ingress-azure.png "ArcGIS Enterprise site ingress")
 *
 * The Application Gateway is deployed into the subnet specified by the "subnet_id" variable or, 
 * if the variable is not set, "app-gateway-subnet-2" subnet of the site's VNet.
 *
 * The Application Gateway is configured with both public and private frontend IP configurations.
 * The public frontend configuration is assigned a public IP address, while the
 * private frontend configuration is assigned a static private IP address specified by 
 * the "ingress_private_ip" variable.
 *
 * The module creates a Private DNS Zone for the deployment's FQDN and links it to the
 * virtual network, allowing internal resolution of the FQDN to the Application Gateway's
 * private IP address.
 *
 * If "dns_zone_name" and "dns_zone_resource_group_name" variables are set, a public DNS A record
 * is also created in the specified DNS zone, pointing the deployment's FQDN to the 
 * public IP address of the Application Gateway.  
 *
 * The Application Gateway's listeners, backend pools, health probes, and routing rules are
 * dynamically configured from the settings defined by the "routing_rules" variable. 
 * By default, the routing rules are set to route traffic to port 443 of 
 * "enterprise-base" and "notebook-server" backend pools.
 *
 * All the HTTPS listeners use the SSL certificate stored in the site's Key Vault. The certificate's
 * secret ID must be specified by the "ssl_certificate_secret_id" variable.
 *
 * The module also generates a CA root certificate, configures the Application Gateway 
 * to use it as trusted certificate in the backend settings, 
 * and stores the certificate and its private key in the Key Vault as secrets.
 *
 * Requests to port 80 on both the public and private frontend IPs are redirected to port 443.
 *
 * The Application Gateway's monitoring subsystem consists of:
 *
 * * An Azure Monitor metric alert that notifies the site's alert action group when
 *   the Application Gateway's unhealthy host count exceeds 0.
 * * A Log Analytics workspace that collects the Application Gateway's logs.
 * * An Azure Monitor dashboard "${var.site_id}-${var.deployment_id}" that visualizes the key metrics and logs of the Application Gateway.
 *
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 *
 * | Key Vault secret name | Description |
 * |--------------------|-------------|
 * | site-alerts-action-group-id | Site's alert action group ID |
 * | storage-account-key | Site's storage account key |
 * | storage-account-name | Site's storage account name |
 * | subnets | VNet subnet IDs |
 * | vm-identity-id | VM identity ID |
 * | vnet-id | VNet ID |
 *
 * ### Secrets Written by the Module
 *
 * | Secret Name | Description |
 * |-------------|-------------|
 * | ${var.deployment_id}-deployment-fqdn | Deployment's FQDN |
 * | ${var.deployment_id}-ca-private-key | Private key of the CA root certificate |
 * | ${var.deployment_id}-ca-root-cert | Self-signed root certificate used by Application Gateway to validate the backend's identity | 
 * | ${var.deployment_id}-backend-address-pools | JSON-encoded map of backend address pool names to their IDs |
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
    key = "arcgis/azure/enterprise-ingress/ingress.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.58"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2"
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

data "azurerm_key_vault_secret" "site_alerts_action_group_id" {
  name         = "site-alerts-action-group-id"
  key_vault_id = module.site_core_info.vault_id
}

locals {
  app_gateway_subnet_id = var.subnet_id == null ? element(module.site_core_info.app_gateway_subnets, 1) : var.subnet_id

  # Get a distinct list of backend address pools from the routing rules
  pools = distinct(flatten([
    for routing in var.routing_rules : [
      for rule in routing.rules : rule.backend_pool
    ]
  ]))

  # Flatten the list of rules to use in dynamic blocks
  all_backend_http_settings = flatten([
    for routing in var.routing_rules : [
      for rule in routing.rules :
      {
        backend_pool    = rule.backend_pool
        backend_port    = rule.backend_port
        backend_path    = try(rule.backend_path, null)
        override_host   = try(rule.override_host, false)
        protocol        = routing.protocol
        name            = rule.name
        probe           = rule.probe
        paths           = rule.paths
        request_timeout = try(rule.request_timeout, 60)
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

# Generate the Private Key
resource "tls_private_key" "ca_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create Self-Signed Certificate using the generated Private Key
resource "tls_self_signed_cert" "ca_root_cert" {
  private_key_pem = tls_private_key.ca_private_key.private_key_pem

  # Mark this as an actual Authority
  is_ca_certificate = true

  subject {
    common_name  = "Internal Root CA"
    organization = var.site_id
  }

  validity_period_hours = 175200 # 20 years

  allowed_uses = [
    "cert_signing", # Required to sign the leaf certificates
    "crl_signing",  # Required to sign revocation lists
    "digital_signature"
  ]
}

# Store the Private Key in Azure Key Vault
resource "azurerm_key_vault_secret" "ca_private_key" {
  name         = "${var.deployment_id}-ca-private-key"
  value        = tls_private_key.ca_private_key.private_key_pem
  key_vault_id = module.site_core_info.vault_id
}

# Store the Certificate (.cer) for App Gateway to use as Trusted Root
resource "azurerm_key_vault_secret" "ca_root_cert" {
  name         = "${var.deployment_id}-ca-root-cert"
  value        = tls_self_signed_cert.ca_root_cert.cert_pem
  key_vault_id = module.site_core_info.vault_id
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

# Create the Application Gateway for the site
resource "azurerm_application_gateway" "ingress" {
  name                = "${var.site_id}-${var.deployment_id}"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location
  zones               = var.zones

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
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

  # Create frontend ports for each listener defined by routing_rules variable.
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
      name                                = backend_http_settings.value.name
      cookie_based_affinity               = "Disabled"
      port                                = backend_http_settings.value.backend_port
      path                                = backend_http_settings.value.backend_path
      protocol                            = backend_http_settings.value.protocol
      request_timeout                     = backend_http_settings.value.request_timeout
      probe_name                          = backend_http_settings.value.name
      trusted_root_certificate_names      = ["trusted-root"]
      pick_host_name_from_backend_address = backend_http_settings.value.override_host
      connection_draining {
        enabled           = true
        drain_timeout_sec = backend_http_settings.value.request_timeout
      }
    }
  }

  dynamic "probe" {
    for_each = local.all_backend_http_settings

    content {
      name                = probe.value.name
      protocol            = "Https"
      path                = probe.value.probe
      interval            = 60
      timeout             = 30
      unhealthy_threshold = 3
      # If override_host is true, use the host name from the backend HTTP settings; otherwise, use the deployment FQDN.
      host                                      = probe.value.override_host ? null: var.deployment_fqdn
      pick_host_name_from_backend_http_settings = probe.value.override_host ? true : null

      match {
        status_code = [200]
      }
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
      default_backend_address_pool_name  = url_path_map.value.rules[0].backend_pool
      default_backend_http_settings_name = url_path_map.value.rules[0].name

      dynamic "path_rule" {
        for_each = url_path_map.value.rules

        content {
          name                       = path_rule.value.name
          paths                      = path_rule.value.paths
          backend_address_pool_name  = path_rule.value.backend_pool
          backend_http_settings_name = path_rule.value.name
          # If the rule has a backend_path defined, create a rewrite rule set to
          # rewrite the path and/or host header for requests routed to this rule.
          rewrite_rule_set_name      = try(path_rule.value.backend_path, null) != null ? path_rule.value.name : null
        }
      }
    }
  }

  dynamic "rewrite_rule_set" {
    # For all rules that have backend_path defined, create a rewrite rule set to rewrite the host header and/or the path.
    for_each = { for k, v in local.all_backend_http_settings : k => v if v.backend_path != null }

    content {
      name = rewrite_rule_set.value.name

      rewrite_rule {
        name          = "XForwardedHostRewrite"
        rule_sequence = 100

        request_header_configuration {
          header_name  = "X-Forwarded-Host"
          header_value = "{http_req_host}" # var.deployment_fqdn
        }
      }

      rewrite_rule {
        name          = "LocationRewrite"
        rule_sequence = 200

        condition {
          variable    = "http_resp_Location"
          pattern     = "(https?):\\/\\/[^\\/]+:${rewrite_rule_set.value.backend_port}\\/(?:arcgis|${rewrite_rule_set.value.name})(.*)$"
          ignore_case = true
        }

        response_header_configuration {
          header_name  = "Location"
          header_value = "{http_resp_Location_1}://{http_req_host}/${rewrite_rule_set.value.name}{http_resp_Location_2}"
        }
      }
    }
  }

  ssl_certificate {
    name                = "cert"
    key_vault_secret_id = var.ssl_certificate_secret_id
  }

  trusted_root_certificate {
    name = "trusted-root"
    data = tls_self_signed_cert.ca_root_cert.cert_pem
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = var.ssl_policy
  }

  # See https://trust.arcgis.com/en/customer-documents/ArcGIS_Enterprise_Web_Application_Filter_Rules.pdf
  firewall_policy_id = azurerm_web_application_firewall_policy.arcgis_enterprise.id

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
  ttl                 = 3600
  records = [
    var.ingress_private_ip
  ]
}

# Create a record in the public DNS zone that points the deployment's FQDN
resource "azurerm_dns_a_record" "public_dns_entry" {
  count = var.dns_zone_name != null && var.dns_zone_resource_group_name != null ? 1 : 0
  # Use "@" for apex/root records; otherwise, strip the zone suffix to get a relative name
  name                = var.deployment_fqdn == var.dns_zone_name ? "@" : trimsuffix(var.deployment_fqdn, ".${var.dns_zone_name}")
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 3600
  records = [
    azurerm_public_ip.ingress.ip_address
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
