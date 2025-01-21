/**
 * # Organization Terraform Module for ArcGIS Enterprise on Kubernetes
 *
 * The module deploys ArcGIS Enterprise on Kubernetes in Azure AKS cluster and creates an ArcGIS Enterprise organization.
 *
 * ![ArcGIS Enterprise on Kubernetes](arcgis-enterprise-k8s-organization.png "ArcGIS Enterprise on Kubernetes")  
 *
 * The module uses [Helm Charts for ArcGIS Enterprise on Kubernetes](https://links.esri.com/enterprisekuberneteshelmcharts/1.2.0/deploy-guide) distributed separately from the module.
 * The Helm charts package for the version used by the deployment must be extracted in the module's `helm-charts/arcgis-enterprise/<Helm charts version>` directory.
 *
 * The module:
 * 
 * 1. Creates a Kubernetes pod to execute Enterprise Admin CLI commands,
 * 2. Creates an Azure storage account with private endpoint for the blob store and a blob container for the organization object store, 
 * 3. Create Helm release to deploy ArcGIS Enterprise on Kubernetes,
 * 4. Updates the DR settings to use the specified storage class and size for staging volume,
 * 5. Registers backup store using blob container in azure storage account specified by "storage-account-name" Key Vault secret.
 *
 * The module retrieves the following secrets from the site's Key Vault:
 * 
 * | Secret Name | Description |
 * | --- | --- |
 * | acr-login-server | Azure Container Registry login server |
 * | aks-identity-principal-id | AKS cluster managed identity principal ID |
 * | aks-identity-client-id | AKS cluster managed identity client ID |
 * | storage-account-name | Azure storage account name |
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 * 
 * * Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID,
 *   and ARM_CLIENT_SECRET environment variables.
 * * AKS cluster configuration information must be provided in ~/.kube/config file.
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
    key = "arcgis-enterprise/azure/arcgis-enterprise-k8s/organization.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.16"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26"
    }
  }

  required_version = ">= 1.10.0"
}

provider "azurerm" {
  storage_use_azuread = true
  features {}
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_secret" "acr_login_server" {
  name         = "acr-login-server"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "aks_identity_principal_id" {
  name         = "aks-identity-principal-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "aks_identity_client_id" {
  name         = "aks-identity-client-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_storage_account" "site_storage" {
  name                = module.site_core_info.storage_account_name
  resource_group_name = module.site_core_info.resource_group_name
}

locals {
  container_registry         = data.azurerm_key_vault_secret.acr_login_server.value
  enterprise_admin_cli_image = "${local.container_registry}/enterprise-admin-cli:${var.enterprise_admin_cli_version}"

  # The AKS cluster uses managed identity authentication for ACR access, while the Helm charts require setting container reqistry credentials.
  container_registry_username = "Azure"
  container_registry_password = "Azure"

  configure_cloud_stores = true

  app_version         = yamldecode(file("./helm-charts/arcgis-enterprise/${var.helm_charts_version}/Chart.yaml")).appVersion
  backup_store_suffix = replace(local.app_version, ".", "-")
  backup_store        = "azure-backup-store-${local.backup_store_suffix}"

  backup_root_dir = "${var.deployment_id}/${local.app_version}"
}

# Module to retrieve site core information from the Key Vault.
module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

# Kubernetes secret with ArcGIS Enterprise credentials used by the Enterprise Admin CLI pod.
resource "kubernetes_secret" "admin_cli_credentials" {
  metadata {
    name      = "admin-cli-credentials"
    namespace = var.deployment_id
  }

  data = {
    username = var.admin_username
    password = var.admin_password
  }
}

# Kubernetes pod used to execute Enterprise Admin CLI commands using "kubectl exec".
resource "kubernetes_pod" "enterprise_admin_cli" {
  metadata {
    name      = "enterprise-admin-cli"
    namespace = var.deployment_id
  }

  spec {
    container {
      name  = "enterprise-admin-cli"
      image = local.enterprise_admin_cli_image
      env {
        name  = "ARCGIS_ENTERPRISE_URL"
        value = "https://${var.deployment_fqdn}/${var.arcgis_enterprise_context}"
      }
      env {
        name = "ARCGIS_ENTERPRISE_USER"
        value_from {
          secret_key_ref {
            name = kubernetes_secret.admin_cli_credentials.metadata[0].name
            key  = "username"
          }
        }
      }
      env {
        name  = "ARCGIS_ENTERPRISE_PASSWORD_FILE"
        value = "/var/run/secrets/admin-cli-credentials/password"
      }
      resources {
        limits = {
          cpu    = "500m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
      }
      command = [
        "sleep", "infinity"
      ]
      volume_mount {
        name       = "admin-cli-credentials"
        read_only  = true
        mount_path = "/var/run/secrets/admin-cli-credentials"
      }
    }
    volume {
      name = "admin-cli-credentials"
      secret {
        secret_name = kubernetes_secret.admin_cli_credentials.metadata[0].name
      }
    }
    restart_policy = "Always"
  }

  depends_on = [
    kubernetes_secret.admin_cli_credentials
  ]
}

# ArcGIS Enterprise license file must be placed in the Helm chart's user-inputs directory.
resource "local_sensitive_file" "license_file" {
  content  = file(var.authorization_file_path)
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/license.json"
}

# Copy cloud-config.json file to the Helm chart's user-inputs directory if the file path is specified.
resource "local_sensitive_file" "cloud_config_json_file" {
  count    = var.cloud_config_json_file_path != null ? 1 : 0
  content  = file(var.cloud_config_json_file_path)
  filename = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/cloud-config.json"
}

# Create Azure storage account and blob container for the organization object store.
module "azure_storage" {
  count                       = local.configure_cloud_stores && var.cloud_config_json_file_path == null ? 1 : 0
  source                      = "./modules/storage"
  azure_region                = var.azure_region
  site_id                     = var.site_id
  deployment_id               = var.deployment_id
  subnet_id                   = module.site_core_info.internal_subnets[0]
  cloud_config_json_file_path = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}/user-inputs/cloud-config.json"
  client_id                   = data.azurerm_key_vault_secret.aks_identity_client_id.value
  principal_id                = data.azurerm_key_vault_secret.aks_identity_principal_id.value
}

# Deploy ArcGIS Enterprise on Kubernetes using Helm chart.
resource "helm_release" "arcgis_enterprise" {
  name      = "arcgis"
  chart     = "./helm-charts/arcgis-enterprise/${var.helm_charts_version}"
  namespace = var.deployment_id
  # timeout   = 21600 # 6 hours
  timeout = 3600 # 1 hour

  set_sensitive {
    name  = "configure.admin.password"
    value = var.admin_password
  }

  set_sensitive {
    name  = "configure.securityQuestionAnswer"
    value = var.security_question_answer
  }

  set_sensitive {
    name  = "upgrade.token"
    value = var.upgrade_token
  }

  values = [
    "${file("./helm-charts/arcgis-enterprise/${var.helm_charts_version}/configure.yaml")}",
    yamlencode({
      image = {
        registry   = local.container_registry
        repository = var.image_repository_prefix
        username   = local.container_registry_username
        password   = local.container_registry_password
      }
      install = {
        enterpriseFQDN              = var.deployment_fqdn
        context                     = var.arcgis_enterprise_context
        allowedPrivilegedContainers = true
        configureWaitTimeMin        = var.configure_wait_time_min
        ingress = {
          ingressServiceUseClusterIP = true
          tls = {
            # selfSignCN = var.deployment_fqdn
            secretName = "listener-tls-secret"
          }
        }
        k8sClusterDomain = var.k8s_cluster_domain
      }
      common = {
        verbose = var.common_verbose
      }
      configure = {
        enabled           = var.configure_enterprise_org
        systemArchProfile = var.system_arch_profile
        licenseFile       = "user-inputs/license.json"
        licenseTypeId     = var.license_type_id
        admin = {
          username  = var.admin_username
          email     = var.admin_email
          firstName = var.admin_first_name
          lastName  = var.admin_last_name
        }
        securityQuestionIndex   = var.security_question_index
        cloudConfigJsonFilename = local.configure_cloud_stores || var.cloud_config_json_file_path != null ? "user-inputs/cloud-config.json" : null
        logSetting              = var.log_setting
        logRetentionMaxDays     = var.log_retention_max_days
        storage                 = var.storage
      }
      upgrade = {
        mandatoryUpdateTargetId = var.mandatory_update_target_id
        licenseFile             = "user-inputs/license.json"
      }
    })
  ]

  depends_on = [
    local_sensitive_file.license_file,
    local_sensitive_file.cloud_config_json_file,
    kubernetes_pod.enterprise_admin_cli,
    module.azure_storage
  ]
}

# Update DR settings to use the specified storage class and size for staging volume.
module "update_dr_settings" {
  source        = "./modules/cli-command"
  namespace     = var.deployment_id
  admin_cli_pod = kubernetes_pod.enterprise_admin_cli.metadata[0].name
  command = [
    "gis", "update-dr-settings",
    "--storage-class", var.staging_volume_class,
    "--size", var.staging_volume_size,
    "--timeout", var.backup_job_timeout
  ]
  depends_on = [
    helm_release.arcgis_enterprise
  ]
}

# Register default backup store in Microsoft Azure blobs 
module "register_azure_backup_store" {
  source        = "./modules/cli-command"
  namespace     = var.deployment_id
  admin_cli_pod = kubernetes_pod.enterprise_admin_cli.metadata[0].name
  command = [
    "gis", "register-az-backup-store",
    "--store", local.backup_store,
    "--storage-account", module.site_core_info.storage_account_name,
    "--account-endpoint-url", trimsuffix(module.site_core_info.storage_account_blob_endpoint, "/"),
    "--client-id", data.azurerm_key_vault_secret.aks_identity_client_id.value,
    "--root", local.backup_root_dir,
    "--is-default"
  ]
  depends_on = [
    module.update_dr_settings
  ]
}

