/**
 * # Terraform module run_chef
 * 
 * Terraform module run_chef runs Cinc client in zero mode on Azure VMs in specified roles.
 * 
 * The module runs az_run_chef.py python script that creates a Key Vault secret with Chef JSON attributes and
 * runs Azure Managed command on the deployment's Azure VMs in specific roles.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/azure/?view=azure-python) package must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured
 *
 *  Cinc client and Chef Cookbooks for ArcGIS must be installed on the target Azure VMs.
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

resource "null_resource" "run_chef" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    environment = {
      JSON_ATTRIBUTES = nonsensitive(base64encode(var.json_attributes))
    }

    command = "python -m az_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -j ${var.json_attributes_secret} -v ${data.azurerm_key_vault.site_vault.name} -e ${var.execution_timeout}"
  }
}
