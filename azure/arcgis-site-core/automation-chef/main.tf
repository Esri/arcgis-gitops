/**
 * # Terraform module automation-chef
 *
 * The module provisions AWS resources required for ArcGIS Enterprise site configuration management 
 * using IT automation tool Chef/Cinc:
 *
 * * Copies Chef/Cinc client setups and Chef cookbooks for ArcGIS distribution archive from the URLs specified
 * in [automation-chef-files.json](manifests/automation-chef-files.json) file to the private repository S3 bucket
 * * Creates SSM documents for the ArcGIS Enterprise site
 * 
 * The S3 URLs are stored in SSM parameters:
 *
 * | SSM parameter name | Description |
 * | --- | --- |
 * | /arcgis/${var.site_id}/chef-client-url/${os} | S3 URLs of Cinc Client setup for the operating systems |
 * | /arcgis/${var.site_id}/cookbooks-url | S3 URL of Chef cookbooks for ArcGIS distribution archive |
 *
 * SSM documents created by the module:
 * 
 * | SSM document name | Description |
 * | --- | --- |
 * | ${var.site_id}-bootstrap | Installs Chef/Cinc Client and Chef Cookbooks for ArcGIS on EC2 instances |
 * | ${var.site_id}-clean-up | Deletes temporary files created by Chef runs |
 * | ${var.site_id}-install-awscli | Installs AWS CLI on EC2 instances |
 * | ${var.site_id}-efs-mount | Mounts EFS targets on EC2 instances |
 * | ${var.site_id}-run-chef | Runs Chef in solo ode with specified JSON attributes |
 *
 * ## Requirements
 * 
 * On the machine where Terraform is executed:
 *
 * * Python 3.8 or later with [AWS SDK for Python (Boto3)](https://aws.amazon.com/sdk-for-python/) package must be installed
 * * Path to aws/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the automation-chef module path (because [automation-chef-files.json](manifests/automation-chef-files.json) uses relative path to the Chef cookbooks archive)
 * * AWS credentials must be configured.
 * * AWS region must be specified by AWS_DEFAULT_REGION environment variable.
 *
 * Before using the module, the repository S3 bucket must be created by infrastructure-core terraform module.
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
    key = "arcgis-enterprise/azure/automation-chef.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.16"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true
  features {
  }
}

# data "azurerm_client_config" "current" {}

# Module to retrieve site core information from the Key Vault.
module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

module "az_copy_files" {
  source                        = "../../modules/az_copy_files"
  storage_account_blob_endpoint = module.site_core_info.storage_account_blob_endpoint
  container_name                = "repository"
  index_file                    = "manifests/automation-chef-files.json"
}

resource "azurerm_key_vault_secret" "chef_client_urls" {
  for_each     = var.chef_client_paths
  name         = "chef-client-url-${each.key}"
  value        = "${module.site_core_info.storage_account_blob_endpoint}repository/${var.chef_client_paths[each.key].path}"
  key_vault_id = module.site_core_info.vault_id
}

resource "azurerm_key_vault_secret" "arcgis_cookbooks_url" {
  name         = "cookbooks-url"
  value        = "${module.site_core_info.storage_account_blob_endpoint}repository/${var.arcgis_cookbooks_path}"
  key_vault_id = module.site_core_info.vault_id
}

resource "azurerm_key_vault_secret" "chef_client_log_level" {
  name         = "chef-client-log-level"
  value        = "info"
  key_vault_id = module.site_core_info.vault_id
}
