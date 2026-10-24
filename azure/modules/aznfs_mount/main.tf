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

data "azurerm_resources" "enterprise_vault" {
  resource_group_name = "${var.enterprise_id}-infrastructure-core"

  required_tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISRole         = "enterprise-vault"
  }
}

data "azurerm_key_vault" "enterprise_vault" {
  name                = data.azurerm_resources.enterprise_vault.resources[0].name
  resource_group_name = data.azurerm_resources.enterprise_vault.resource_group_name
}

resource "null_resource" "mount" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    environment = {
      JSON_PARAMETERS = base64encode(jsonencode({
        NETWORK_PATH = var.network_path
        MOUNT_POINT  = var.mount_point
      }))
    }

    command = "python -m az_run_shell_script -s ${var.enterprise_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -f ${path.module}/scripts/mount.sh -v ${data.azurerm_key_vault.enterprise_vault.name}"
  }
}
