# Copyright 2025-2026 Esri
#
# Licensed under the Apache License, Version 2.0 (the "License");
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

resource "azurerm_recovery_services_vault" "deployment" {
  name                = "${var.enterprise_id}-${var.deployment_id}-recovery"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  sku                 = "Standard"

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}

resource "azurerm_backup_policy_vm" "fileserver" {
  name                = "fileserver-daily"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.deployment.name
  policy_type         = "V2"
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = var.fileserver_backup_time
  }

  retention_daily {
    count = var.fileserver_backup_retention_days
  }
}

resource "azurerm_backup_protected_vm" "fileserver" {
  resource_group_name = azurerm_resource_group.deployment_rg.name
  recovery_vault_name = azurerm_recovery_services_vault.deployment.name
  source_vm_id        = module.azvm_fileserver.vm_id
  backup_policy_id    = azurerm_backup_policy_vm.fileserver.id
}