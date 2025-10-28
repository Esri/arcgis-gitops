/*
 * # Terraform module clean_up
 * 
 * Terraform module deletes files in specific directories on deployment VMs in specific roles. 
 * Optionally, if the uninstall_chef_client variable is set to true, the module also uninstalls Chef client on the instances. 
 *
 * The module uses az_clean_up.py script to run {var.site-id}-clean-up Azure Run Command on the deployment's VMs in specific roles.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured
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
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

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

resource "null_resource" "clean_up" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    command = "python -m az_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -f ${join(",", var.directories)} ${var.uninstall_chef_client ? "-u" : ""} -v ${data.azurerm_key_vault.site_vault.name} "
  }
}
