/**
* # Packer Template for Base ArcGIS Enterprise on Windows Images
*
* The Packer templates builds VM images for a specific base ArcGIS Enterprise deployment.
*
* The images are built from a Windows OS base image specified by Key Vault secret "vm-image-${var.os}".
*
* The template first copies installation media for the ArcGIS Enterprise version and required third party dependencies from My Esri and public repositories to the private "repository" blob container in Azure storage account specified by "storage-account-name" Key Vault Secret. The files to copy are specified in ../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json index file.
*
* Then the template uses python scripts to run Azure Managed Run Command on the source VM instances.
*
* 1. Install Azure CLI
* 2. Install Cinc Client and Chef Cookbooks for ArcGIS
* 3. Download setups from the private "repository" blob container in Azure storage account.
* 4. Install base ArcGIS Enterprise applications
* 5. Install patches for the base ArcGIS Enterprise applications
* 6. Delete unused files, uninstall Cinc Client, run sysprep
*
* IDs of the images are saved in "vm-image-${var.site_id}-${var.deployment_id}-primary" and "vm-image-${var.site_id}-${var.deployment_id}-standby" Key Vault secrets.
*
* ## Requirements
*
* On the machine where Packer is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, and azure-mgmt-compute azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured using "az login" CLI command.
* My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
*
* ## Key Vault Secrets
*
* The template reads the following Key Vault secrets:
*
* | Key Vault secret name | Description |
* |-----------------------|-------------|
* | chef-client-url-${var.os} | Chef Client URL |
* | cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
* | storage-account-name | Private repository storage account name |
* | vm-identity-client-id | Managed identity client Id |
* | vm-identity-id | Managed identity resource Id |
* | vm-image-${var.os} | Source VM Image Id |
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

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

data "azure-keyvaultsecret" "vm_image" {
  vault_name = var.vault_name
  secret_name = "vm-image-${var.os}"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "vm_identity_id" {
  vault_name = var.vault_name
  secret_name = "vm-identity-id"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "vm_identity_client_id" {
  vault_name = var.vault_name
  secret_name = "vm-identity-client-id"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "chef_client_url" {
  vault_name = var.vault_name
  secret_name = "chef-client-url-${var.os}"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "cookbooks_url" {
  vault_name = var.vault_name
  secret_name = "cookbooks-url"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "storage_account_name" {
  vault_name = var.vault_name
  secret_name = "storage-account-name"
  use_azure_cli_auth = true
}

locals{
  manifest_file_path = "${path.root}/../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  dotnet_setup       = local.manifest.arcgis.repository.metadata.dotnet_setup
  web_deploy_setup   = local.manifest.arcgis.repository.metadata.web_deploy_setup
  
  software_dir       = "C:/Software/*"

  storage_account_blob_endpoint = "https://${data.azure-keyvaultsecret.storage_account_name.value}.blob.core.windows.net"
  
  src_image_tokens = split("/", data.azure-keyvaultsecret.vm_image.value)
  src_image_publisher = local.src_image_tokens[8]
  src_image_offer = local.src_image_tokens[12]
  src_image_sku = local.src_image_tokens[14]
  src_image_version = local.src_image_tokens[16]

  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  dst_image_name = "${var.site_id}-${var.deployment_id}-${var.arcgis_version}-${var.os}-${local.timestamp}"
  machine_role = "packer-main"
}

source "azure-arm" "main" {
  communicator = "winrm"
  winrm_use_ssl = true
  winrm_insecure = true
  winrm_timeout = "5m"
  winrm_username = "packer"

  image_offer = local.src_image_offer
  image_publisher = local.src_image_publisher
  image_sku = local.src_image_sku
  image_version = local.src_image_version
  location = var.azure_region
  os_disk_size_gb = var.os_disk_size
  os_type = "Windows"
  managed_image_storage_account_type = "Premium_LRS"
  managed_image_name = local.dst_image_name
  managed_image_resource_group_name = "${var.site_id}-infrastructure-core"
  user_assigned_managed_identities = [
    data.azure-keyvaultsecret.vm_identity_id.value
  ]
  use_azure_cli_auth = true
  vm_size = var.vm_size
  skip_create_image = var.skip_create_image
  
  # Retrieve PowerShell script from the Instance Metadata Service (IMDS) user data and run it.
  custom_script = join("", [
    "powershell -ExecutionPolicy Unrestricted -NoProfile -NonInteractive -Command \"",
    "$userData = (Invoke-RestMethod -Headers @{Metadata=$true} -Method GET -Uri http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01$([char]38)format=text); ",
    "$contents = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($userData)); ",
    "set-content -path c:\\Windows\\Temp\\userdata.ps1 -value $contents -Encoding UTF8; ",
    ". c:\\Windows\\Temp\\userdata.ps1 -AzureCliUrl ${var.azure_cli_url};\""])

  user_data_file = "./scripts/userdata.ps1"

  azure_tags = {
    "ArcGISSiteId"     = var.site_id
    "ArcGISDeploymentId" = var.deployment_id
    "ArcGISRole"       = local.machine_role
  }
}

build {
  name = var.deployment_id
 
  sources = [
    "source.azure-arm.main"
  ]

  # provisioner "windows-restart" {}

 # Bootstrap the VM
  provisioner "shell-local" {
    command = "python -m az_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -c ${data.azure-keyvaultsecret.chef_client_url.value} -k ${data.azure-keyvaultsecret.cookbooks_url.value} -v ${var.vault_name}"
  }

  # Copy files to private blob repository
  provisioner "shell-local" {
    command = "python -m az_copy_files -f ${local.manifest_file_path} -a ${local.storage_account_blob_endpoint} -c repository"
  }

  # Download setups from the private repository
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(templatefile(
        local.manifest_file_path, 
        { 
          account_name = data.azure-keyvaultsecret.storage_account_name.value, 
          container_name = "repository"
          client_id = data.azure-keyvaultsecret.vm_identity_client_id.value
        }
      ))
    }

    command = "python -m az_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-files -v ${var.vault_name} -e 1200"
  }

  # Install
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          run_as_password = var.run_as_password
          configure_windows_firewall = true
          configure_cloud_settings   = false
          repository = {
            archives = local.archives_dir
            setups = "C:\\Software\\Setups"
          }
          server = {
            install_dir = "C:\\Program Files\\ArcGIS\\Server"
            install_system_requirements = true
            wa_name = var.server_web_context
          }
          web_adaptor = {
            install_system_requirements = true
            dotnet_setup_path = "${local.archives_dir}\\${local.dotnet_setup}"
            web_deploy_setup_path = "${local.archives_dir}\\${local.web_deploy_setup}"
            admin_access = true
            reindex_portal_content = false
          }
          data_store = {
            install_dir = "C:\\Program Files\\ArcGIS\\DataStore"
            setup_options = "ADDLOCAL=relational"
            data_dir = "C:\\arcgisdatastore"
            install_system_requirements = true
            preferredidentifier = "hostname"
          }
          portal = {
            install_dir = "C:\\Program Files\\ArcGIS\\Portal"
            install_system_requirements = true
            data_dir = "C:\\arcgisportal"
            preferredidentifier = "hostname"
            wa_name = var.portal_web_context
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::system]",
          "recipe[esri-iis::install]",
          "recipe[arcgis-enterprise::install_portal]",
          "recipe[arcgis-enterprise::webstyles]",
          "recipe[arcgis-enterprise::install_portal_wa]",
          "recipe[arcgis-enterprise::install_server]",
          "recipe[arcgis-enterprise::install_server_wa]",
          "recipe[arcgis-enterprise::install_datastore]"
        ]
      }))
    }

    command = "python -m az_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-install -v ${var.vault_name} -e 14400"
  }

  # Install patches
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version = var.arcgis_version
          configure_cloud_settings = false
          repository = {
            patches = local.patches_dir
          }
          portal = {
            patches = var.arcgis_portal_patches
          }
          server = {
            patches = var.arcgis_server_patches
          }
          data_store = {
            patches = var.arcgis_data_store_patches
          }
          web_adaptor = {
            patches = var.arcgis_web_adaptor_patches
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::install_patches]"
        ]
      }))
    }

    command = "python -m az_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-patches -v ${var.vault_name} -e 3600"
  }

  # Clean up
  provisioner "shell-local" {
    command = "python -m az_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -f \"${local.software_dir},C:/Program Files/ArcGIS/Portal/etc/ssl/*\" -v ${var.vault_name}"
  }

  # Restart the VM to finalize the installation
  provisioner "windows-restart" {}

  # Generalize the image
  provisioner "powershell" {
    inline = [
      "$sysprep = \"$env:SystemRoot\\System32\\Sysprep\\Sysprep.exe\"",
      "Start-Process $sysprep -ArgumentList '/oobe /generalize /quiet /shutdown /mode:vm' -Wait"
    ]
  }

  # Save the build artifacts metadata in packer-manifest.json file.
  # Note: New builds add new artifacts to packer-manifest.json file.
  post-processor "manifest" {
    output = "main-packer-manifest.json"
    strip_path = true
  }

  # Retrieve the image Id from main-packer-manifest.json manifest file and save it in a key vault secret.
  post-processor "shell-local" {
    command = "python -m publish_artifact -v ${var.vault_name} -s vm-image-${var.site_id}-${var.deployment_id}-primary -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }

  post-processor "shell-local" {
    command = "python -m publish_artifact -v ${var.vault_name} -s vm-image-${var.site_id}-${var.deployment_id}-standby -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }
}