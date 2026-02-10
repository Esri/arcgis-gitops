/**
 * # Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes
 * 
 * This Terraform module creates and manages an Application Gateway for Containers (AGC) that
 * routes traffic to ArcGIS Enterprise on Kubernetes ingress service.
 * 
 * ![ArcGIS Enterprise on Kubernetes Ingress](arcgis-enterprise-k8s-ingress-azure.png "ArcGIS Enterprise on Kubernetes Ingress")  
 *
 * The module manages the following resources:
 * * An Application Gateway for Containers
 * * A frontend for the application gateway
 * * A Kubernetes namespace for ArcGIS Enterprise on Kubernetes deployment in the AKS cluster
 * * A secret with the TLS certificate for the HTTPS listener
 * * A secret with the CA certificate for the backend TLS policy
 * * A Kubernetes Gateway resource with HTTPS listener for the deployment frontend
 * * A Kubernetes HTTPRoute resource that routes the gateway's traffic to 
 *   port 443 of arcgis-ingress-nginx service
 * * A Kubernetes BackendTLSPolicy resource required for the end-to-end HTTPS route
 * * A Kubernetes HealthCheckPolicy resource for the gateway
 * * A Web Application Firewall policy and associates it with the Application Gateway
 * * A policy association with the gateway Kubernetes resource
 * * A private DNS zone and a CNAME record that points the deployment's FQDN
 * 
 * If a public DNS zone name and resource group name are provided, a CNAME record in the DNS zone
 * that points the deployment's FQDN to the Application Gateway's frontend DNS name
 * 
 * The ingress monitoring subsystem consists of:
 *
 * * An Azure Monitor metric alert that notifies the site's alert action group when
 *   the Application Gateway's healthy host count is 0
 * * A Log Analytics workspace that collects the Application Gateway's logs
 * * A shared dashboard "{var.site_id}-{var.deployment_id}-ingress" that visualizes 
 *   the key metrics and logs of the Application Gateway for Containers
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
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID,
 *   and ARM_CLIENT_SECRET environment variables.
 * * AKS cluster configuration information must be provided in ~/.kube/config file.
 */

# Copyright 2024-2026 Esri
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
    key = "arcgis/azure/enterprise-k8s/ingress.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.58"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
  }

  required_version = ">= 1.10.0"
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

locals {
  namespace           = var.deployment_id
  backend_service     = "arcgis-ingress-nginx"
  gateway_name        = "gateway-01"
  listener_tls_secret = "listener-tls-secret"
  ca_bundle_secret    = "ca-bundle-secret"

  # Split the deployment FQDN into DNS zone name and CNAME record
  parts = split(".", var.deployment_fqdn)
  first_dot_index = length(local.parts[0]) 
  cname_record = substr(var.deployment_fqdn, 0, local.first_dot_index)
  private_dns_zone_name = substr(var.deployment_fqdn, local.first_dot_index + 1, -1)
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

resource "azurerm_resource_group" "deployment_rg" {
  name     = "${var.site_id}-${var.deployment_id}-ingress"
  location = var.azure_region
}

# Create an Application Gateway for Containers
resource "azurerm_application_load_balancer" "ingress" {
  name                = "${var.site_id}-${var.deployment_id}"
  location            = azurerm_resource_group.deployment_rg.location
  # The AGC must be created in the cluster resource group because the ALB controller's
  # managed identity scope is limited to the cluster resource group.
  resource_group_name = "${var.site_id}-k8s-cluster"
}

# Associate the Application Gateway with app-gateway-subnet-1 subnet
resource "azurerm_application_load_balancer_subnet_association" "ingress" {
  name                         = azurerm_application_load_balancer.ingress.name
  application_load_balancer_id = azurerm_application_load_balancer.ingress.id
  subnet_id                    = module.site_core_info.app_gateway_subnets[0]
}

# Create a frontend for the deployment in the Application Load Balancer
resource "azurerm_application_load_balancer_frontend" "public_frontend" {
  name                         = var.deployment_id
  application_load_balancer_id = azurerm_application_load_balancer.ingress.id
}

# Create a namespace for the deployment
resource "kubernetes_namespace" "arcgis_enterprise" {
  metadata {
    name = local.namespace
  }
}

# Create a secret with the TLS certificate for the HTTPS listener
resource "kubernetes_secret" "listener_tls_secret" {
  metadata {
    namespace = local.namespace
    name      = local.listener_tls_secret
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = file(var.tls_certificate_path)
    "tls.key" = file(var.tls_private_key_path)
  }

  depends_on = [
    kubernetes_namespace.arcgis_enterprise
  ]
}

# Create a secret with the CA certificate for the backend TLS policy
resource "kubernetes_secret" "ca_bundle_secret" {
  metadata {
    namespace = local.namespace
    name      = local.ca_bundle_secret
  }

  data = {
    "ca.crt" = file(var.ca_certificate_path)
  }

  depends_on = [
    kubernetes_namespace.arcgis_enterprise
  ]
}

# Create a Gateway with HTTPS listener for the deployment frontend.
# If a valid backend TLS policy is configured for the HTTP route,
# the HTTPS listener does not actually terminate the SSL connection.
resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.gateway_name
      namespace = local.namespace
      annotations = {
        "alb.networking.azure.io/alb-id" = azurerm_application_load_balancer.ingress.id
      }
    }
    spec = {
      gatewayClassName = "azure-alb-external"
      listeners = [{
        name     = "https-listener"
        port     = 443
        protocol = "HTTPS"
        allowedRoutes = {
          namespaces = {
            from = "Same"
          }
        }
        tls = {
          mode = "Terminate"
          certificateRefs = [{
            kind  = "Secret"
            group = ""
            name  = local.listener_tls_secret
          }]
        }
      }]
      addresses = [{
        type  = "alb.networking.azure.io/alb-frontend"
        value = azurerm_application_load_balancer_frontend.public_frontend.name
      }]
    }
  }

  depends_on = [
    kubernetes_namespace.arcgis_enterprise,
    kubernetes_secret.listener_tls_secret
  ]
}

# Create an HTTP route that routes the gateway's traffic to 
# port 443 of arcgis-ingress-nginx service.
resource "kubernetes_manifest" "http_route" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "https-route"
      namespace = local.namespace
    }
    spec = {
      parentRefs = [{
        name = local.gateway_name
      }]
      rules = [{
        # Configurable request timeouts are not yet supported by 
        # Application Gateway for Containers. The actual timeouts are 60s.
        # '0s' or '0' signifies an infinite timeout
        timeouts = {
          request        = "0s"
          backendRequest = "0s"
        }
        backendRefs = [{
          name = local.backend_service
          port = 443
        }]
      }]
    }
  }

  depends_on = [
    kubernetes_manifest.gateway
  ]
}

# Create a backend TLS policy required for the end-to-end HTTPS route.
resource "kubernetes_manifest" "tls_policy" {
  manifest = {
    apiVersion = "alb.networking.azure.io/v1"
    kind       = "BackendTLSPolicy"
    metadata = {
      name      = "arcgis-ingress-tls-policy"
      namespace = local.namespace
    }
    spec = {
      targetRef = {
        kind      = "Service"
        name      = local.backend_service
        namespace = local.namespace
        group     = ""
      }
      default = {
        sni = var.deployment_fqdn
        ports = [{
          port = 443
        }]
        verify = {
          caCertificateRef = {
            group = ""
            kind  = "Secret"
            name  = local.ca_bundle_secret
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.arcgis_enterprise,
    kubernetes_secret.ca_bundle_secret
  ]
}

resource "kubernetes_manifest" "health_check_policy" {
  manifest = {
    apiVersion = "alb.networking.azure.io/v1"
    kind       = "HealthCheckPolicy"
    metadata = {
      name      = "gateway-health-check-policy"
      namespace = local.namespace
    }
    spec = {
      targetRef = {
        group     = ""
        kind      = "Service"
        name      = local.backend_service
        namespace = local.namespace
      }
      default = {
        interval           = "5s"
        timeout            = "30s"
        healthyThreshold   = 1
        unhealthyThreshold = 3
        port               = 443
        http = {
          host = var.deployment_fqdn
          path = "/${var.arcgis_enterprise_context}/admin"
          match = {
            statusCodes = [{
              start = 200
              end   = 399
            }]
          }
        }
        useTLS = true
      }
    }
  }

  depends_on = [
    kubernetes_namespace.arcgis_enterprise
  ]
}

# Associate a Web Application Firewall policy with the Application Gateway for Containers.
resource "azurerm_application_load_balancer_security_policy" "agc_security_policy" {
  name                               = azurerm_application_load_balancer.ingress.name
  application_load_balancer_id       = azurerm_application_load_balancer.ingress.id
  location                           = azurerm_resource_group.deployment_rg.location
  web_application_firewall_policy_id = azurerm_web_application_firewall_policy.arcgis_enterprise.id
}

# Associate the WAF policy with the gateway in the Kubernetes cluster.
resource "kubernetes_manifest" "waf_policy" {
  manifest = {
    apiVersion = "alb.networking.azure.io/v1"
    kind       = "WebApplicationFirewallPolicy"
    metadata = {
      name      = "arcgis-waf-policy"
      namespace = local.namespace
    }
    spec = {
      targetRef = {
        group     = "gateway.networking.k8s.io"
        kind      = "Gateway"
        name      = local.gateway_name
        namespace = local.namespace
      }
      webApplicationFirewall = {
        id = azurerm_web_application_firewall_policy.arcgis_enterprise.id
      }
    }
  }
}

# Application Gateway for Containers does not support private IP addresses (and private front ends).
# CNAME record cannot be used in the apex @ record of the DNS zone.
# Private DNS zones do not support alias A records.
# So the private DNS zone is not created for var.deployment_fqdn but for 
# the upper level domain.
resource "azurerm_private_dns_zone" "deployment_fqdn" {
  name                = local.private_dns_zone_name
  resource_group_name = azurerm_resource_group.deployment_rg.name

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Private DNS Zone Virtual Network Link
resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = azurerm_private_dns_zone.deployment_fqdn.name
  resource_group_name   = azurerm_resource_group.deployment_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.deployment_fqdn.name
  virtual_network_id    = module.site_core_info.vnet_id
}

# Create a record in the private DNS zone that points the deployment's FQDN 
# to the Application Gateway's frontend DNS name.
resource "azurerm_private_dns_cname_record" "private_cname" {
  name                = local.cname_record
  zone_name           = azurerm_private_dns_zone.deployment_fqdn.name
  resource_group_name = azurerm_resource_group.deployment_rg.name
  ttl                 = 3600
  record              = azurerm_application_load_balancer_frontend.public_frontend.fully_qualified_domain_name
}

# Create a CNAME record in the public DNS zone that points the deployment's FQDN 
# to the Application Gateway's frontend FQDN if var.dns_zone_name is set.
resource "azurerm_dns_cname_record" "public_cname" {
  count               = var.dns_zone_name != null && var.dns_zone_resource_group_name != null ? 1 : 0
  name                = trimsuffix(var.deployment_fqdn, ".${var.dns_zone_name}")
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group_name
  ttl                 = 3600
  record = azurerm_application_load_balancer_frontend.public_frontend.fully_qualified_domain_name
}

# Store the deployment FQDN in Key Vault
resource "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  value        = var.deployment_fqdn
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}
