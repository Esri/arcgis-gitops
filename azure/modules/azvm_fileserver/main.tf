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

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
  }
}

data "azurerm_key_vault_secret" "image" {
  count        = var.fileserver_deployment_id == null ? 1 : 0
  name         = "${var.deployment_id}-vm-image-fileserver"
  key_vault_id = var.vault_id
}

data "azurerm_key_vault_secret" "shared_private_dns" {
  count        = var.fileserver_deployment_id == null ? 0 : 1
  name         = "${var.fileserver_deployment_id}-fileserver-private-dns"
  key_vault_id = var.vault_id
}

data "azurerm_key_vault_secret" "shared_security_group_id" {
  count        = var.fileserver_deployment_id == null ? 0 : 1
  name         = "${var.fileserver_deployment_id}-fileserver-security-group-id"
  key_vault_id = var.vault_id
}

data "azurerm_key_vault_secret" "shared_vm_id" {
  count        = var.fileserver_deployment_id == null ? 0 : 1
  name         = "${var.fileserver_deployment_id}-fileserver-vm-id"
  key_vault_id = var.vault_id
}

data "azurerm_subnet" "fileserver" {
  count                = var.fileserver_deployment_id == null ? 1 : 0
  name                 = split("/", var.subnet_id)[10]
  virtual_network_name = split("/", var.subnet_id)[8]
  resource_group_name  = split("/", var.subnet_id)[4]

  lifecycle {
    postcondition {
      condition     = self.network_security_group_id != null && self.network_security_group_id != ""
      error_message = "The file-server subnet must have an existing network security group shared with the primary and standby VMs."
    }
  }
}

locals {
  create_fileserver = var.fileserver_deployment_id == null
  private_dns       = local.create_fileserver ? "fileserver.${var.deployment_id}.${var.enterprise_id}.internal" : nonsensitive(data.azurerm_key_vault_secret.shared_private_dns[0].value)
  security_group_id = local.create_fileserver ? data.azurerm_subnet.fileserver[0].network_security_group_id : nonsensitive(data.azurerm_key_vault_secret.shared_security_group_id[0].value)
  vm_id             = local.create_fileserver ? azurerm_windows_virtual_machine.fileserver[0].id : nonsensitive(data.azurerm_key_vault_secret.shared_vm_id[0].value)
}

resource "azurerm_network_interface" "fileserver" {
  count               = local.create_fileserver ? 1 : 0
  name                = "fileserver-nic"
  location            = var.azure_region
  resource_group_name = var.resource_group_name

  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISRole         = "fileserver"
  }
}

resource "azurerm_windows_virtual_machine" "fileserver" {
  count               = local.create_fileserver ? 1 : 0
  name                = "fileserver"
  resource_group_name = var.resource_group_name
  location            = var.azure_region
  zone                = "1"
  size                = var.vm_size

  admin_username  = var.admin_username
  admin_password  = var.admin_password
  source_image_id = data.azurerm_key_vault_secret.image[0].value

  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true

  network_interface_ids = [azurerm_network_interface.fileserver[0].id]

  additional_capabilities {
    ultra_ssd_enabled = var.data_disk_storage_account_type == "UltraSSD_LRS"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 256
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.vm_identity_id]
  }

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISRole         = "fileserver"
  }

  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password
    ]
  }
}

resource "azurerm_managed_disk" "data" {
  count                = local.create_fileserver ? 1 : 0
  name                 = "fileserver-data-disk"
  location             = var.azure_region
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  disk_iops_read_write = var.data_disk_iops
  disk_mbps_read_write = var.data_disk_throughput_mbps
  zone                 = "1"

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISRole         = "fileserver"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count              = local.create_fileserver ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.data[0].id
  virtual_machine_id = azurerm_windows_virtual_machine.fileserver[0].id
  lun                = 0
  caching            = contains(["PremiumV2_LRS", "UltraSSD_LRS"], var.data_disk_storage_account_type) ? "None" : "ReadWrite"
}

resource "azurerm_virtual_machine_extension" "initialize_data_disk" {
  count                = local.create_fileserver ? 1 : 0
  name                 = "initialize-fileserver-data-disk"
  virtual_machine_id   = azurerm_windows_virtual_machine.fileserver[0].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    # Compress the embedded script to stay below cmd.exe's 8191-character limit.
    commandToExecute = join(" ", [
      "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"& {",
      "$ErrorActionPreference = 'Stop'; try {",
      "$bytes = [Convert]::FromBase64String('${base64gzip(file("${path.module}/initialize_data_disk.ps1"))}');",
      "$stream = [IO.MemoryStream]::new($bytes);",
      "$gzip = [IO.Compression.GzipStream]::new($stream, [IO.Compression.CompressionMode]::Decompress);",
      "$reader = [IO.StreamReader]::new($gzip);",
      "& ([scriptblock]::Create($reader.ReadToEnd())); exit 0",
      "} catch { [Console]::Error.WriteLine($_.ToString()); [Console]::Error.WriteLine($_.ScriptStackTrace); exit 1 }",
      "finally { if ($reader) { $reader.Dispose() }; if ($gzip) { $gzip.Dispose() }; if ($stream) { $stream.Dispose() } }",
      "}\""
    ])
  })

  depends_on = [azurerm_virtual_machine_data_disk_attachment.data]
}

resource "azurerm_private_dns_a_record" "fileserver" {
  count               = local.create_fileserver ? 1 : 0
  name                = "fileserver.${var.deployment_id}"
  zone_name           = "${var.enterprise_id}.internal"
  resource_group_name = "${var.enterprise_id}-infrastructure-core"
  ttl                 = 300
  records             = [azurerm_windows_virtual_machine.fileserver[0].private_ip_address]
}

resource "azurerm_key_vault_secret" "private_dns" {
  count        = local.create_fileserver ? 1 : 0
  name         = "${var.deployment_id}-fileserver-private-dns"
  value        = local.private_dns
  key_vault_id = var.vault_id

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}

resource "azurerm_key_vault_secret" "security_group_id" {
  count        = local.create_fileserver ? 1 : 0
  name         = "${var.deployment_id}-fileserver-security-group-id"
  value        = local.security_group_id
  key_vault_id = var.vault_id

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}

resource "azurerm_key_vault_secret" "vm_id" {
  count        = local.create_fileserver ? 1 : 0
  name         = "${var.deployment_id}-fileserver-vm-id"
  value        = azurerm_windows_virtual_machine.fileserver[0].id
  key_vault_id = var.vault_id

  tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
  }
}

moved {
  from = azurerm_network_interface.fileserver
  to   = azurerm_network_interface.fileserver[0]
}

moved {
  from = azurerm_windows_virtual_machine.fileserver
  to   = azurerm_windows_virtual_machine.fileserver[0]
}

moved {
  from = azurerm_managed_disk.data
  to   = azurerm_managed_disk.data[0]
}

moved {
  from = azurerm_virtual_machine_data_disk_attachment.data
  to   = azurerm_virtual_machine_data_disk_attachment.data[0]
}

moved {
  from = azurerm_virtual_machine_extension.initialize_data_disk
  to   = azurerm_virtual_machine_extension.initialize_data_disk[0]
}

moved {
  from = azurerm_private_dns_a_record.fileserver
  to   = azurerm_private_dns_a_record.fileserver[0]
}

moved {
  from = azurerm_key_vault_secret.private_dns
  to   = azurerm_key_vault_secret.private_dns[0]
}

moved {
  from = azurerm_key_vault_secret.security_group_id
  to   = azurerm_key_vault_secret.security_group_id[0]
}