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

resource "null_resource" "prepare" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    environment = {
      JSON_PARAMETERS = base64encode(jsonencode(var.expected_account == null ? {} : {
        EncodedExpectedAccount = base64encode(var.expected_account)
      }))
    }

    command = join(" ", [
      "python -u -m az_run_shell_script ${var.expected_account == null ? "--stream-output" : ""} -s ${var.enterprise_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)}",
      "--vm-resource-id \"${var.vm_resource_id}\"",
      "--prepend \"${path.module}/scripts/parameters.ps1\"",
      "--prepend \"${path.module}/scripts/image_identity.ps1\"",
      "--prepend \"${path.module}/scripts/replace_sid_in_descriptor.ps1\"",
      "--prepend \"${path.module}/scripts/reconcile_image_sid.ps1\"",
      "-f \"${path.module}/scripts/prepare_data_disk.ps1\" -v ${data.azurerm_key_vault.enterprise_vault.name}"
    ])
  }
}