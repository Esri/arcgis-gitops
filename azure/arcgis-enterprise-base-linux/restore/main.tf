# Copyright 2026 Esri
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
    key = "terraform/arcgis/enterprise-base-linux/restore.tfstate"
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

module "backup_enterprise_core_info" {
  source        = "../../modules/enterprise_core_info"
  enterprise_id = var.backup_enterprise_id
}

module "target_enterprise_core_info" {
  source        = "../../modules/enterprise_core_info"
  enterprise_id = var.enterprise_id
}

data "azurerm_key_vault_secret" "vm_identity_client_id" {
  name         = "vm-identity-client-id"
  key_vault_id = module.target_enterprise_core_info.vault_id
}

locals {
  shared_location = "/mnt/fileserver/gisdata/arcgisbackup/webgisdr"
}

# Run webgisdr utility with import option on the primary VM.
module "arcgis_enterprise_webgisdr_import" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-webgisdr-import"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  execution_timeout      = var.execution_timeout
  json_attributes = jsonencode({
    arcgis = {
      run_as_user = var.run_as_user
      portal = {
        install_dir      = "/opt"
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
          AZURE_BLOB_ACCOUNT_NAME             = module.backup_enterprise_core_info.storage_account_name
          AZURE_BLOB_ACCOUNT_ENDPOINT_SUFFIX  = "core.windows.net"
          AZURE_BLOB_CONTAINER_NAME           = "webgisdr-backups"
          AZURE_BLOB_CREDENTIALTYPE           = "userAssignedIdentity"
          AZURE_BLOB_USER_MI_CLIENT_ID        = data.azurerm_key_vault_secret.vm_identity_client_id.value
          BACKUP_BLOB_ACCOUNT_NAME            = module.backup_enterprise_core_info.storage_account_name
          BACKUP_BLOB_ACCOUNT_ENDPOINT_SUFFIX = "core.windows.net"
          BACKUP_BLOB_CONTAINER_NAME          = "content-backups"
          BACKUP_BLOB_CREDENTIALTYPE          = "userAssignedIdentity"
          BACKUP_BLOB_USER_MI_CLIENT_ID       = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::webgisdr_import]"
    ]
  })
}
