# Copyright 2024-2026 Esri
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

data "azurerm_key_vault_secret" "chef_client_url" {
  key_vault_id = data.azurerm_key_vault.enterprise_vault.id
  name  = "chef-client-url-${var.os}"
}

data "azurerm_key_vault_secret" "cookbooks_url" {
  key_vault_id = data.azurerm_key_vault.enterprise_vault.id
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
    command = "python -m az_bootstrap -s ${var.enterprise_id} -d ${var.deployment_id} -m ${join(",", var.machine_roles)} -c ${local.chef_client_url} -k ${local.chef_cookbooks_url} -v ${data.azurerm_key_vault.enterprise_vault.name}"
  }
}
