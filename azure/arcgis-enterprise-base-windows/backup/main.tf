/**
 * # Backup Terraform Module for Base ArcGIS Enterprise on Windows
 *
 * The Terraform module creates a backup of base ArcGIS Enterprise deployment on Windows platform.
 *
 * The module runs WebGISDR utility with 'export' option on the primary VM of the deployment.
 *
 * The WebGISDR backups are stored in "webgisdr-backups" blob container of the site's Azure Storage account.
 * The Portal for ArcGIS content store backups are stored in "content-backups" blob container.
 *
 * ## Requirements
 *
 * The base ArcGIS Enterprise must be configured on the deployment by application terraform module
 * for base ArcGIS Enterprise on Windows.
 *
 * The user assigned managed identity assigned to the VMs must have Storage Blob Data Owner role on
 * the site's storage account used for storing backups.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.9 or later must be installed
 * * azure-identity, azure-keyvault-secrets, and azure-mgmt-compute azure-storage-blob Azure Python SDK packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured using "az login" CLI command
 *
 * ## Key Vault Secrets
 *
 * The module reads the following Key Vault secrets:
 *
 * | Key Vault secret name | Description |
 * |-----------------------|-------------|
 * | storage-account-key | Site's storage account key |
 * | storage-account-name | Site's storage account name |
 * | subnets | VNet subnets IDs |
 * | vm-identity-client-id | Client ID of the user-assigned VM identity |
 * | vnet-id | VNet ID |
 *
 * > The storage-account-name, storage-account-key, subnets, and vnet-id
 *   secrets are retrieved by backup_site_core_info module.
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
    key = "terraform/arcgis/enterprise-base-windows/backup.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_secret" "vm_identity_client_id" {
  name         = "vm-identity-client-id"
  key_vault_id = module.site_core_info.vault_id
}

locals {
  shared_location = "\\\\\\\\FILESERVER\\\\arcgisbackup\\\\webgisdr"
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

# Run webgisdr utility with export option on the primary VM.
module "arcgis_enterprise_webgisdr_export" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-webgisdr-export"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  execution_timeout      = var.execution_timeout
  json_attributes = jsonencode({
    arcgis = {
      run_as_user     = var.run_as_user
      run_as_password = var.run_as_password
      portal = {
        install_dir      = "C:\\Program Files\\ArcGIS\\Portal"
        webgisdr_timeout = var.execution_timeout
        webgisdr_properties = {
          PORTAL_ADMIN_URL                    = var.portal_admin_url
          PORTAL_ADMIN_USERNAME               = var.admin_username
          PORTAL_ADMIN_PASSWORD               = var.admin_password
          PORTAL_ADMIN_PASSWORD_ENCRYPTED     = false
          BACKUP_RESTORE_MODE                 = var.backup_restore_mode
          SHARED_LOCATION                     = local.shared_location
          INCLUDE_SCENE_TILE_CACHES           = false
          BACKUP_STORE_PROVIDER               = "AzureBlob"
          AZURE_BLOB_ACCOUNT_NAME             = module.site_core_info.storage_account_name
          AZURE_BLOB_ACCOUNT_ENDPOINT_SUFFIX  = "core.windows.net"
          AZURE_BLOB_CONTAINER_NAME           = "webgisdr-backups"
          AZURE_BLOB_CREDENTIALTYPE           = "userAssignedIdentity"
          AZURE_BLOB_USER_MI_CLIENT_ID        = data.azurerm_key_vault_secret.vm_identity_client_id.value
          BACKUP_BLOB_ACCOUNT_NAME            = module.site_core_info.storage_account_name
          BACKUP_BLOB_ACCOUNT_ENDPOINT_SUFFIX = "core.windows.net"
          BACKUP_BLOB_CONTAINER_NAME          = "content-backups"
          BACKUP_BLOB_CREDENTIALTYPE          = "userAssignedIdentity"
          BACKUP_BLOB_USER_MI_CLIENT_ID       = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::webgisdr_export]"
    ]
  })
}
