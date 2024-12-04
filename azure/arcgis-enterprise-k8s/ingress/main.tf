/**
 * # Ingress Terraform Module for Base ArcGIS Enterprise on Kubernetes
 * 
 * This module manages the ingress resources for the deployment of ArcGIS Enterprise on Kubernetes:
 *
 * 1. Retrieves ID of the Application Gateway for Containers from "alb-id" secret of
 *    the site'ss Key Vault and creates frontend for the deployment in the load balancer.
 * 2. Creates Kubernetes namespace for ArcGIS Enterprise on Kubernetes deployment in 
 *    Azure Kubernetes Service (AKS) cluster.
 * 3. Create a secret with the TLS certificate for the HTTPS listener.
 * 4. Create a secret with the CA certificate for the backend TLS policy.
 * 5. Creates a Kubernetes Gateway resource with HTTPS listener for the deployment frontend.
 * 6. Creates a Kubernetes HTTPRoute resource that routes the gateway's traffic to 
 *    port 443 of arcgis-ingress-nginx service.
 * 7. Creates a Kubernetes BackendTLSPolicy resource required for the end-to-end HTTPS route.
 * 8. Creates a Kubernetes HealthCheckPolicy resource for the gateway.
 *
 * If hosted zone name is provided, a CNAME record is created in the hosted zone
 * that points the deployment's FQDN to the Application Gateway's frontend DNS name.
 * 
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID,
 *   and ARM_CLIENT_SECRET environment variables.
 * * AKS cluster configuration information must be provided in ~/.kube/config file.
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
    key = "arcgis-enterprise/azure/arcgis-enterprise-k8s/ingress.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.6"
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

data "azurerm_key_vault" "site_vault" {
  name                = var.site_id
  resource_group_name = "${var.site_id}-infrastructure-core"
}

# Retrieve the Application Load Balancer ID from the Key Vault
data "azurerm_key_vault_secret" "alb_id" {
  name         = "alb-id"
  key_vault_id = data.azurerm_key_vault.site_vault.id
}

locals {
  namespace           = var.deployment_id
  backend_service     = "arcgis-ingress-nginx"
  gateway_name        = "gateway-01"
  listener_tls_secret = "listener-tls-secret"
  ca_bundle_secret    = "ca-bundle-secret"
}

# Create a frontend for the deployment in the Application Load Balancer
resource "azurerm_application_load_balancer_frontend" "deployment_frontend" {
  name                         = var.deployment_id
  application_load_balancer_id = data.azurerm_key_vault_secret.alb_id.value
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
        "alb.networking.azure.io/alb-id" = data.azurerm_key_vault_secret.alb_id.value
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
        value = azurerm_application_load_balancer_frontend.deployment_frontend.name
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
        timeouts = {
          request        = "600s"
          backendRequest = "600s"
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

# Create a CNAME record in the hosted zone that points the deployment's FQDN 
# to the Application Gateway's frontend DNS name.
resource "azurerm_dns_cname_record" "example" {
  count               = var.hosted_zone_name != null ? 1 : 0
  name                = "${var.deployment_fqdn}."
  zone_name           = var.hosted_zone_name
  resource_group_name = var.hosted_zone_resource_group
  ttl                 = 300
  record              = azurerm_application_load_balancer_frontend.deployment_frontend.fully_qualified_domain_name
}
