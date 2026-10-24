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
    key = "arcgis-enterprise/azure/automation-chef.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.58"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true
  features {
  }
}

# data "azurerm_client_config" "current" {}

# Module to retrieve enterprise core information from the Key Vault.
module "enterprise_core_info" {
  source  = "../../modules/enterprise_core_info"
  enterprise_id = var.enterprise_id
}

module "az_copy_files" {
  source                        = "../../modules/az_copy_files"
  storage_account_blob_endpoint = module.enterprise_core_info.storage_account_blob_endpoint
  container_name                = "repository"
  index_file                    = "manifests/automation-chef-files.json"
}

resource "azurerm_key_vault_secret" "chef_client_urls" {
  for_each     = var.chef_client_paths
  name         = "chef-client-url-${each.key}"
  value        = "${module.enterprise_core_info.storage_account_blob_endpoint}repository/${var.chef_client_paths[each.key].path}"
  key_vault_id = module.enterprise_core_info.vault_id
}

resource "azurerm_key_vault_secret" "arcgis_cookbooks_url" {
  name         = "cookbooks-url"
  value        = "${module.enterprise_core_info.storage_account_blob_endpoint}repository/${var.arcgis_cookbooks_path}"
  key_vault_id = module.enterprise_core_info.vault_id
}

resource "azurerm_key_vault_secret" "chef_client_log_level" {
  name         = "chef-client-log-level"
  value        = "info"
  key_vault_id = module.enterprise_core_info.vault_id
}
