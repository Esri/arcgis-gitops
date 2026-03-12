/**
 * # Packer Template for Base ArcGIS Enterprise on Linux Images
 * 
 * The Packer template builds VM images for a specific base ArcGIS Enterprise deployment on Linux.
 * 
 * The VM image is built from the operating system's base image specified by Key Vault secret "vm-image-${var.os}".
 * 
 * The template copies installation media for the ArcGIS Enterprise version
 * and required third party dependencies from My Esri and public repositories 
 * to the private repository blob container. The files to be copied are specified in 
 * ../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json index file.
 * 
 * The template uses python scripts to run Azure Managed Run Command on the source VM instances:
 * 
 * 1. Install Azure CLI and NFS tools
 * 2. Install Cinc Client and Chef Cookbooks for ArcGIS
 * 3. Download setups from the private repository Azure Storage blob container
 * 4. Install OpenJDK, Apache Tomcat, Portal for ArcGIS, ArcGIS Server, ArcGIS Data Store, and ArcGIS Web Adaptor for Java
 * 5. Install patches for the ArcGIS Enterprise components
 * 6. Delete temporary files and uninstall Cinc Client
 * 
 * IDs of the images are saved in "vm-image-${var.deployment_id}-primary" 
 * and "vm-image-${var.deployment_id}-standby" Key Vault secrets.
 * 
 * ## Requirements
 *
 * On the machine where Packer is executed:
 *
 * * Python 3.9 or later must be installed
 * * azure-identity, azure-keyvault-secrets, and azure-mgmt-compute azure-storage-blob Azure Python SDK packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure CLI must be installed and configured
 * * Azure credentials must be configured using "az login" CLI command
 * * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD
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
 * 
 * The template writes the following Key Vault secrets:
 *
 * | Key Vault secret name | Description |
 * |-----------------------|-------------|
 * | vm-image-${var.deployment_id}-primary | Built image Id for primary VM |
 * | vm-image-${var.deployment_id}-standby | Built image Id for standby VM |
 * | vm-image-${var.deployment_id}-os | Operating system ID |
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

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

data "azure-keyvaultsecret" "vm_image" {
  vault_name         = var.vault_name
  secret_name        = "vm-image-${var.os}"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "vm_identity_id" {
  vault_name         = var.vault_name
  secret_name        = "vm-identity-id"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "vm_identity_client_id" {
  vault_name         = var.vault_name
  secret_name        = "vm-identity-client-id"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "chef_client_url" {
  vault_name         = var.vault_name
  secret_name        = "chef-client-url-${var.os}"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "cookbooks_url" {
  vault_name         = var.vault_name
  secret_name        = "cookbooks-url"
  use_azure_cli_auth = true
}

data "azure-keyvaultsecret" "storage_account_name" {
  vault_name         = var.vault_name
  secret_name        = "storage-account-name"
  use_azure_cli_auth = true
}

locals {
  manifest_file_path = "${path.root}/../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  java_tarball       = local.manifest.arcgis.repository.metadata.java_tarball
  java_version       = local.manifest.arcgis.repository.metadata.java_version
  tomcat_tarball     = local.manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version     = local.manifest.arcgis.repository.metadata.tomcat_version

  software_dir = "/opt/software/setups/*"

  storage_account_blob_endpoint = "https://${data.azure-keyvaultsecret.storage_account_name.value}.blob.core.windows.net"

  src_image_tokens    = split("/", data.azure-keyvaultsecret.vm_image.value)
  src_image_publisher = local.src_image_tokens[8]
  src_image_offer     = local.src_image_tokens[12]
  src_image_sku       = local.src_image_tokens[14]
  src_image_version   = local.src_image_tokens[16]

  timestamp      = formatdate("YYYYMMDDhhmm", timestamp())
  dst_image_name = "${var.site_id}-${var.deployment_id}-${var.arcgis_version}-${var.os}-${local.timestamp}"
  machine_role   = "packer-main"
}

source "azure-arm" "main" {
  communicator   = "ssh"
  ssh_username   = "packer"
  ssh_timeout    = "5m"

  image_offer     = local.src_image_offer
  image_publisher = local.src_image_publisher
  image_sku       = local.src_image_sku
  image_version   = local.src_image_version
  location        = var.azure_region
  os_disk_size_gb = var.os_disk_size
  os_type         = "Linux"
  managed_image_storage_account_type = "Premium_LRS"
  managed_image_name                 = local.dst_image_name
  managed_image_resource_group_name  = "${var.site_id}-infrastructure-core"
  user_assigned_managed_identities = [
    data.azure-keyvaultsecret.vm_identity_id.value
  ]
  use_azure_cli_auth = true
  vm_size            = var.vm_size
  skip_create_image  = var.skip_create_image

  azure_tags = {
    "ArcGISSiteId"       = var.site_id
    "ArcGISDeploymentId" = var.deployment_id
    "ArcGISRole"         = local.machine_role
  }
}

build {
  name = var.deployment_id

  sources = [
    "source.azure-arm.main"
  ]

  # Run an OS-specific script on the VM to install Azure CLI and NFS tools.
  provisioner "shell-local" {
    env = {
      JSON_PARAMETERS = base64encode(jsonencode({
        AZURE_CLI_VERSION = var.azure_cli_version
      }))
    }
    command = "python -m az_run_shell_script -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -v ${var.vault_name} -e 3600 -f scripts/${var.os}.sh"
  }

  # Bootstrap the VM
  provisioner "shell-local" {
    command      = "python -m az_bootstrap -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -c ${data.azure-keyvaultsecret.chef_client_url.value} -k ${data.azure-keyvaultsecret.cookbooks_url.value} -v ${var.vault_name}"
    valid_exit_codes = [0, 1]
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
          account_name   = data.azure-keyvaultsecret.storage_account_name.value
          container_name = "repository"
          client_id      = data.azure-keyvaultsecret.vm_identity_client_id.value
        }
      ))
    }
    command = "python -m az_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-files -v ${var.vault_name} -e 1200"
  }

  # Install ArcGIS Enterprise components
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        java = {
          version      = local.java_version
          tarball_path = "${local.archives_dir}/${local.java_tarball}"
        }
        tomcat = {
          version      = local.tomcat_version
          tarball_path = "${local.archives_dir}/${local.tomcat_tarball}"
          install_path = "/opt/tomcat_arcgis_${local.tomcat_version}"
        }
        arcgis = {
          version     = var.arcgis_version
          run_as_user = var.run_as_user
          repository = {
            archives = local.archives_dir
            setups   = "/opt/software/setups"
          }
          web_server = {
            webapp_dir = "/opt/tomcat_arcgis_${local.tomcat_version}/webapps"
          }
          server = {
            install_dir                 = "/opt"
            install_system_requirements = true
            configure_autostart         = true
            wa_name                     = var.server_web_context
          }
          web_adaptor = {
            install_dir = "/opt"
          }
          data_store = {
            install_dir                 = "/opt"
            setup_options               = "-f Relational"
            data_dir                    = "/gisdata/arcgisdatastore"
            configure_autostart         = true
            preferredidentifier         = "hostname"
            install_system_requirements = true
          }
          portal = {
            install_dir                 = "/opt"
            configure_autostart         = true
            install_system_requirements = true
            wa_name                     = var.portal_web_context
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::system]",
          "recipe[esri-tomcat::openjdk]",
          "recipe[esri-tomcat::install]",
          "recipe[arcgis-enterprise::install_portal]",
          "recipe[arcgis-enterprise::webstyles]",
          "recipe[arcgis-enterprise::install_portal_wa]",
          "recipe[arcgis-enterprise::install_server]",
          "recipe[arcgis-enterprise::install_server_wa]",
          "recipe[arcgis-enterprise::install_datastore]"
        ]
      }))
    }
    command = "python -m az_run_chef -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-install -v ${var.vault_name} -e 3600"
  }

  # Install patches
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version     = var.arcgis_version
          run_as_user = var.run_as_user
          repository = {
            patches = local.patches_dir
          }
          portal = {
            install_dir = "/opt"
            patches     = var.arcgis_portal_patches
          }
          server = {
            install_dir = "/opt"
            patches     = var.arcgis_server_patches
          }
          data_store = {
            install_dir = "/opt"
            patches     = var.arcgis_data_store_patches
          }
          web_adaptor = {
            install_dir = "/opt"
            patches     = var.arcgis_web_adaptor_patches
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
    command = "python -m az_clean_up -s ${var.site_id} -d ${var.deployment_id} -m ${local.machine_role} -f ${local.software_dir} -v ${var.vault_name}"
  }

  # Save the build artifacts metadata in packer-manifest.json file.
  post-processor "manifest" {
    output     = "main-packer-manifest.json"
    strip_path = true
  }

  # Retrieve the image Id and save it in key vault secrets for primary and standby VMs.
  post-processor "shell-local" {
    command = "python -m publish_artifact -v ${var.vault_name} -s vm-image-${var.deployment_id}-primary -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }

  post-processor "shell-local" {
    command = "python -m publish_artifact -v ${var.vault_name} -s vm-image-${var.deployment_id}-standby -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }

  # Save the operating system type in key vault secret.
  post-processor "shell-local" {
    command = "az keyvault secret set --vault-name '${var.vault_name}' --name 'vm-image-${var.deployment_id}-os' --value '${var.os}'"
  }
}
