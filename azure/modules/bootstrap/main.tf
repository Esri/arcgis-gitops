/*
 * # Terraform module bootstrap
 * 
 * Terraform module installs or upgrades Chef client and Chef Cookbooks for ArcGIS on Azure VMs.
 *
 * The module uses az_bootstrap.py script to run managed Run Command on the deployment's Azure VMs in the specific roles.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured
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

data "azurerm_resources" "site_vault" {
  resource_group_name = "${var.site_id}-infrastructure-core"

  required_tags = {
    ArcGISSiteId = var.site_id
    ArcGISRole   = "site-vault"
  }
}

data "azurerm_key_vault" "site_vault" {
  name                = data.azurerm_resources.site_vault.resources[0].name
  resource_group_name = data.azurerm_resources.site_vault.resource_group_name
}

data "azurerm_key_vault_secret" "chef_client_url" {
  key_vault_id = data.azurerm_key_vault.site_vault.id
  name  = "chef-client-url-${var.os}"
}

data "azurerm_key_vault_secret" "cookbooks_url" {
  key_vault_id = data.azurerm_key_vault.site_vault.id
  name = "cookbooks-url"
}

locals {
  chef_client_url     = var.chef_client_url != null ? var.chef_client_url : nonsensitive(data.azurerm_key_vault_secret.chef_client_url.value)
  chef_cookbooks_url  = var.chef_cookbooks_url != null ? var.chef_cookbooks_url : nonsensitive(data.azurerm_key_vault_secret.cookbooks_url.value)
}

resource "null_resource" "bootstrap" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "python -m az_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -c ${local.chef_client_url} -k ${local.chef_cookbooks_url} -v ${data.azurerm_key_vault.site_vault.name}"
  }
}
