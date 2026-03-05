/*
 * # Terraform module lv_extend
 * 
 * Terraform module lv_extend extends the logical volume on Azure VMs in a deployment.
 * 
 * The module uses az_run_shell_script python module to run ${var.os}.sh scripts on the deployment's VMs in specific roles.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 *
 * * Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured
 */

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

resource "null_resource" "mount" {
  triggers = {
    always_run = "${timestamp()}"
  }
    
  provisioner "local-exec" {
    environment = {
      JSON_PARAMETERS = base64encode(jsonencode({
      }))
    }

    command = "python -m az_run_shell_script -s ${var.site_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -f ${path.module}/scripts/${var.os}.sh -v ${data.azurerm_key_vault.site_vault.name}" 
  }
}
