/**
 * # Organization Terraform Module for ArcGIS Enterprise on Kubernetes
 *
 * The module deploys ArcGIS Enterprise on Kubernetes in an Azure AKS cluster and creates an ArcGIS Enterprise organization.
 *
 * ![ArcGIS Enterprise on Kubernetes](arcgis-enterprise-k8s-organization.png "ArcGIS Enterprise on Kubernetes")  
 *
 * The module uses the Helm Charts for ArcGIS Enterprise on Kubernetes.
 * The Helm charts package for the ArcGIS Enterprise version used by the deployment 
 * is downloaded from My Esri and extracted in the module's `helm-charts/arcgis-enterprise/<Helm charts version>` directory.
 *
 * The module:
 * 
 * * Creates a Kubernetes pod to execute Enterprise Admin CLI commands
 * * Creates an Azure storage account with private endpoint for the blob store and a blob container for the organization object store
 * * Installs Helm Charts for ArcGIS Enterprise on Kubernetes
 * * Copies ArcGIS Enterprise license file and cloud-config.json file to the Helm chart's user-inputs directory
 * * Create a Helm release to deploy ArcGIS Enterprise on Kubernetes
 * * Updates the DR settings to use the specified storage class and size for staging volume
 * * Registers backup store using blob container in Azure storage account specified by "storage-account-name" Key Vault secret
 *
 * The module retrieves the following secrets from the site's Key Vault:
 * 
 * | Secret Name | Description |
 * | --- | --- |
 * | deployment-fqdn | Fully qualified domain name used for the ArcGIS Enterprise deployment |
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
 * * ArcGIS Online credentials must be set by ARCGIS_ONLINE_PASSWORD and ARCGIS_ONLINE_USERNAME environment variables.
 * * AKS cluster configuration information must be provided in ~/.kube/config file.
 * * Path to azure/scripts directory must be added to PYTHONPATH.
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
    key = "arcgis-enterprise/azure/arcgis-enterprise-k8s/organization.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.58"
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

data "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
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
  deployment_fqdn            = nonsensitive(data.azurerm_key_vault_secret.deployment_fqdn.value)
  container_registry         = nonsensitive(data.azurerm_key_vault_secret.acr_login_server.value)
  enterprise_admin_cli_image = "${local.container_registry}/enterprise-admin-cli:${var.enterprise_admin_cli_version}"

  configure_cloud_stores = true

  backup_store_suffix = replace(var.arcgis_version, ".", "-")
  backup_store        = "azure-backup-store-${local.backup_store_suffix}"
  backup_root_dir     = "${var.deployment_id}/${var.arcgis_version}"

  manifest_file_path = "./manifests/arcgis-enterprise-k8s-files-${var.arcgis_version}.json"
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
      image_pull_policy = "Always"
      env {
        name  = "ARCGIS_ENTERPRISE_URL"
        value = "https://${local.deployment_fqdn}/${var.arcgis_enterprise_context}"
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

# Install Helm charts for ArcGIS Enterprise on Kubernetes.
module "helm_charts" {
  source = "./modules/helm-charts"
  index_file = local.manifest_file_path
  install_dir = "./helm-charts/arcgis-enterprise"
}

# ArcGIS Enterprise license file must be placed in the Helm chart's user-inputs directory.
resource "local_sensitive_file" "license_file" {
  content  = file(var.authorization_file_path)
  filename = "${module.helm_charts.helm_charts_path}/user-inputs/license.json"
  
  depends_on = [
    module.helm_charts
  ]
}

# Copy cloud-config.json file to the Helm chart's user-inputs directory if the file path is specified.
resource "local_sensitive_file" "cloud_config_json_file" {
  count    = var.cloud_config_json_file_path != null ? 1 : 0
  content  = file(var.cloud_config_json_file_path)
  filename = "${module.helm_charts.helm_charts_path}/user-inputs/cloud-config.json"

  depends_on = [
    module.helm_charts
  ]
}

# Create Azure storage account and blob container for the organization object store.
module "azure_storage" {
  count                       = local.configure_cloud_stores && var.cloud_config_json_file_path == null ? 1 : 0
  source                      = "./modules/storage"
  azure_region                = var.azure_region
  site_id                     = var.site_id
  deployment_id               = var.deployment_id
  subnet_id                   = module.site_core_info.internal_subnets[0]
  cloud_config_json_file_path = "${module.helm_charts.helm_charts_path}/user-inputs/cloud-config.json"
  client_id                   = data.azurerm_key_vault_secret.aks_identity_client_id.value
  principal_id                = data.azurerm_key_vault_secret.aks_identity_principal_id.value
}

# Deploy ArcGIS Enterprise on Kubernetes using Helm chart.
resource "helm_release" "arcgis_enterprise" {
  name      = "arcgis"
  chart     = module.helm_charts.helm_charts_path
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
    module.helm_charts.configure_yaml_content,
    yamlencode({
      image = {
        registry   = local.container_registry
        repository = var.image_repository_prefix
        # The AKS cluster uses managed identity authentication for ACR access, 
        # while the Helm charts before 1.5.0 required setting container registry credentials.
        username           = "Azure"
        password           = "Azure"
        authenticationType = "integrated"
      }
      install = {
        enterpriseFQDN              = local.deployment_fqdn
        context                     = var.arcgis_enterprise_context
        allowedPrivilegedContainers = true
        configureWaitTimeMin        = var.configure_wait_time_min
        ingress = {
          ingressServiceUseClusterIP = true
          tls = {
            # selfSignCN = local.deployment_fqdn
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
    module.helm_charts,
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

