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
  required_version = ">= 1.11.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.6"
    }
  }
}

data "azapi_resource" "image" {
  type                   = "Microsoft.Compute/galleries/images/versions@2023-07-03"
  resource_id            = var.settings.image_id
  response_export_values = ["properties.storageProfile"]
}

locals {
  image_data_disks = try([
    for disk in data.azapi_resource.image.output.properties.storageProfile.dataDiskImages :
    disk if disk.lun == 0
  ], [])
  os_profile = merge({
    computerName  = var.settings.name
    adminUsername = var.settings.admin_username
    }, var.settings.windows ? {
    windowsConfiguration = {
      provisionVMAgent       = true
      enableAutomaticUpdates = true
      patchSettings = {
        assessmentMode = "ImageDefault"
        patchMode      = "AutomaticByOS"
      }
    }
    } : {}, var.settings.windows ? {} : {
    linuxConfiguration = merge({
      provisionVMAgent              = true
      disablePasswordAuthentication = var.settings.public_key != null
      patchSettings = {
        assessmentMode = "AutomaticByPlatform"
        patchMode      = "ImageDefault"
      }
      }, var.settings.public_key == null ? {} : {
      ssh = {
        publicKeys = [{
          path    = "/home/${var.settings.admin_username}/.ssh/authorized_keys"
          keyData = var.settings.public_key
        }]
      }
    })
  })
}

resource "azapi_resource" "vm" {
  type      = "Microsoft.Compute/virtualMachines@2024-11-01"
  name      = var.settings.name
  parent_id = var.settings.resource_group_id
  location  = var.settings.location
  identity {
    type         = "UserAssigned"
    identity_ids = [var.settings.identity_id]
  }
  tags                             = var.settings.tags
  replace_triggers_external_values = [var.settings.image_id]
  body = {
    properties = {
      hardwareProfile        = { vmSize = var.settings.size }
      virtualMachineScaleSet = { id = var.settings.scale_set_id }
      securityProfile = {
        securityType     = "TrustedLaunch"
        encryptionAtHost = true
        uefiSettings = {
          secureBootEnabled = true
          vTpmEnabled       = true
        }
      }
      osProfile = local.os_profile
      networkProfile = {
        networkInterfaces = [{ id = var.settings.nic_id, properties = { primary = true } }]
      }
      storageProfile = {
        imageReference = { id = var.settings.image_id }
        osDisk = {
          createOption = "FromImage"
          caching      = "ReadWrite"
          diskSizeGB   = var.settings.os_disk_size
          deleteOption = "Delete"
          managedDisk  = { storageAccountType = "StandardSSD_LRS" }
        }
        dataDisks = [{
          name         = "${var.settings.name}-data"
          lun          = 0
          createOption = "FromImage"
          caching      = "None"
          diskSizeGB   = var.settings.data_disk_size
          deleteOption = "Delete"
          managedDisk  = { storageAccountType = "Premium_LRS" }
        }]
      }
    }
  }
  sensitive_body = var.admin_password == null ? {} : {
    properties = { osProfile = { adminPassword = var.admin_password } }
  }
  lifecycle {
    ignore_changes = [body.properties.osProfile.adminUsername, sensitive_body]
    precondition {
      condition     = try(length(local.image_data_disks) == 1 && local.image_data_disks[0].sizeInGB <= var.settings.data_disk_size, false)
      error_message = "The gallery image must contain data LUN 0 no larger than data_disk_size. Rebuild the image; empty replacement and shrink are prohibited."
    }
    precondition {
      condition     = data.azapi_resource.image.output.properties.storageProfile.osDiskImage.sizeInGB <= var.settings.os_disk_size
      error_message = "os_disk_size cannot be smaller than the gallery image OS disk."
    }
  }
}
