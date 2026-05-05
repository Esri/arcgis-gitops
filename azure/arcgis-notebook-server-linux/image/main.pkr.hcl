/**
 * # Packer Template for ArcGIS Notebook Server on Linux
 * 
 * The Packer template builds VM image for a specific ArcGIS Notebook Server deployment and
 * publishes it to the enterprise Image Gallery.
 * 
 * The VM image is built from the operating system's base image specified by Key Vault secret "vm-image-${var.os}".
 * 
 * The template copies installation media for the ArcGIS Notebook Server version
 * and required third party dependencies from My Esri and public repositories 
 * to the private repository blob container. The files to be copied are specified in 
 * ../manifests/arcgis-notebook-server-azure-files-${var.arcgis_version}.json index file.
 * 
 * The template uses python scripts to run Azure Managed Run Command on the source VM instances:
 * 
 * 1. Install Azure CLI and Docker CE; if gpu_ready is true, install NVIDIA drivers and CUDA toolkit
 * 2. Install Cinc Client and Chef Cookbooks for ArcGIS
 * 3. Download setups from the private repository Azure Storage blob container
 * 4. Install OpenJDK, Apache Tomcat, ArcGIS Notebook Server, and ArcGIS Web Adaptor for Java
 * 5. Install patches for the ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
 * 6. Delete temporary files and uninstall Cinc Client
 * 
 * The image ID is saved in "${var.deployment_id}-vm-image-primary" 
 * and "${var.deployment_id}-vm-image-node" Key Vault secrets.
 * 
 * ## Requirements
 *
 * VM image definition "${var.deployment_id}-${var.arcgis_version}-${var.os}" 
 * must be created in the enterprise Image Gallery before running the template.
 *
 * On the machine where Packer is executed:
 *
 * * Python 3.9 or later must be installed
 * * Azure Python SDK packages azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure CLI must be installed and configured
 * * Azure credentials must be configured using "az login" CLI command
 * * My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD
 *
 * ## Key Vault Secrets
 *
 * The template reads the following Key Vault secrets:
 *
 * | Key Vault secret name     | Description |
 * |---------------------------|-------------|
 * | chef-client-url-${var.os} | Chef Client URL |
 * | cookbooks-url             | Chef Cookbooks for ArcGIS archive URL |
 * | image-gallery-name        | Enterprise Image Gallery name | 
 * | storage-account-name      | Private repository storage account name |
 * | vm-identity-client-id     | Managed identity client ID |
 * | vm-identity-id            | Managed identity resource ID |
 * | vm-image-${var.os}        | Source VM Image ID |
 * 
 * The template writes the following Key Vault secrets:
 *
 * | Key Vault secret name                            | Description |
 * |--------------------------------------------------|-------------|
 * | ${var.deployment_id}-notebook-server-web-context | ArcGIS Notebook Server web context |
 * | ${var.deployment_id}-os                          | Operating system ID |
 * | ${var.deployment_id}-vm-image-node               | Built image ID for additional nodes |
 * | ${var.deployment_id}-vm-image-primary            | Built image ID for primary node |
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

data "azure-keyvaultsecret" "enterprise_ig" {
  vault_name         = var.vault_name
  secret_name        = "image-gallery-name"
  use_azure_cli_auth = true
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

locals {
  manifest_file_path =  "${path.root}/../manifests/arcgis-notebook-server-azure-files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  java_tarball       = local.manifest.arcgis.repository.metadata.java_tarball
  java_version       = local.manifest.arcgis.repository.metadata.java_version
  tomcat_tarball     = local.manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version     = local.manifest.arcgis.repository.metadata.tomcat_version

  software_dir = "/opt/software/setups/*"

  storage_account_blob_endpoint = "https://${data.azure-keyvaultsecret.storage_account_name.value}.blob.core.windows.net"
  
  src_image_tokens = split("/", data.azure-keyvaultsecret.vm_image.value)
  src_image_publisher = local.src_image_tokens[8]
  src_image_offer = local.src_image_tokens[12]
  src_image_sku = local.src_image_tokens[14]
  src_image_version = local.src_image_tokens[16]

  machine_role = "packer-main"
}

source "azure-arm" "main" {
  communicator = "ssh"
  ssh_username = "packer"
  ssh_timeout = "5m"

  location        = var.azure_region
  vm_size         = var.vm_size
  os_disk_size_gb = var.os_disk_size
  os_type         = "Linux"

  managed_image_storage_account_type = "Premium_LRS"
  
  security_type       = "TrustedLaunch"
  encryption_at_host  = true  
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Source Image
  image_offer     = local.src_image_offer
  image_publisher = local.src_image_publisher
  image_sku       = local.src_image_sku
  image_version   = local.src_image_version
  
  # Destination Image
  shared_image_gallery_destination {
    resource_group = "${var.enterprise_id}-infrastructure-core"
    gallery_name   = data.azure-keyvaultsecret.enterprise_ig.value
    image_name     = "${var.deployment_id}-${var.arcgis_version}-${var.os}"
    image_version  = formatdate("YYYY.MMDD.HHMM", timestamp())
    # replication_regions = ["East US"]
  }
  
  user_assigned_managed_identities = [
    data.azure-keyvaultsecret.vm_identity_id.value
  ]
  use_azure_cli_auth = true

  skip_create_image = var.skip_create_image
  
  # Use cloud-init to run an OS-specific script on the VM. 
  # custom_data = base64encode(templatefile(
  #   "${path.root}/scripts/${var.os}-init.sh", 
  #   { 
  #     test = "value"
  #   }
  # ))

  azure_tags = {
    "ArcGISEnterpriseID" = var.enterprise_id
    "ArcGISDeploymentID" = var.deployment_id
    "ArcGISRole"         = local.machine_role
  }
}


build {
  name = var.deployment_id
 
  sources = [
    "source.azure-arm.main"
  ]

  # Wait for cloud-init to finish and check its result. 
  # provisioner "shell" {
  #   inline = [
  #     "echo 'Waiting for cloud-init to finish...'",
  #     "set +e",
  #     "cloud-init status --wait",
  #     "RESULT=$?",
  #     "set -e",
  #     "echo '--- START OF CLOUD-INIT LOGS ---'",
  #     "sudo cat /var/log/cloud-init-output.log",
  #     "echo '--- END OF CLOUD-INIT LOGS ---'",
  #     # Explicitly check the captured result
  #     "if [ $${RESULT} -ne 0 ]; then",
  #     "  echo \"Build failed: cloud-init exited with error code $${RESULT}\"",
  #     "  exit $${RESULT}",
  #     "fi",
  #     "echo 'Cloud-init finished successfully. Continuing build...'"
  #   ]
  # }

  # Run an OS-specific script on the VM to install Azure CLI and Docker CE.
  # If gpu_ready is true, also install NVIDIA drivers and CUDA toolkit.
  provisioner "shell-local" {
    env = {
      JSON_PARAMETERS = base64encode(jsonencode({
        AZURE_CLI_VERSION = var.azure_cli_version
        DOCKER_VERSION = var.docker_version
        GPU_READY = var.gpu_ready ? "true" : "false"
      }))
    }
    command = "python -m az_run_shell_script -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -v ${var.vault_name} -e 3600 -f scripts/${var.os}.sh"
  }

  # Bootstrap the VM
  provisioner "shell-local" {
    command = "python -m az_bootstrap -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -c ${data.azure-keyvaultsecret.chef_client_url.value} -k ${data.azure-keyvaultsecret.cookbooks_url.value} -v ${var.vault_name}"
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
          account_name = data.azure-keyvaultsecret.storage_account_name.value, 
          container_name = "repository"
          client_id = data.azure-keyvaultsecret.vm_identity_client_id.value
        }
      ))
    }

    command = "python -m az_run_chef -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-files -v ${var.vault_name} -e 1200"
  }

  # Install
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        java = {
          version = local.java_version
          tarball_path = "${local.archives_dir}/${local.java_tarball}"
        }
        tomcat = {
          version = local.tomcat_version
          tarball_path = "${local.archives_dir}/${local.tomcat_tarball}"
          install_path = "/opt/tomcat_arcgis_${local.tomcat_version}"
        }
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          configure_autofs = false
          repository = {
            archives = local.archives_dir
            setups = "/opt/software/setups"
          }
          web_server = {
            webapp_dir = "/opt/tomcat_arcgis_${local.tomcat_version}/webapps"
          }
          notebook_server = {
            install_dir = "/opt"
            install_system_requirements = true
            license_level = var.license_level
            configure_autostart = true
            wa_name = var.notebook_server_web_context
          }
          web_adaptor = {
            install_dir = "/opt"
          }
        }
        run_list = [
          "recipe[arcgis-enterprise::system]",
          "recipe[esri-tomcat::openjdk]",
          "recipe[esri-tomcat::install]",
          "recipe[arcgis-notebooks::iptables]",
          "recipe[arcgis-notebooks::restart_docker]",
          "recipe[arcgis-notebooks::install_server]",
          "recipe[arcgis-notebooks::install_server_wa]"                    
        ]
      }))
    }

    command = "python -m az_run_chef -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-install -v ${var.vault_name} -e 3600"
  }

  # Install patches
  provisioner "shell-local" {
    env = {
      JSON_ATTRIBUTES = base64encode(jsonencode({
        arcgis = {
          version = var.arcgis_version
          run_as_user = var.run_as_user
          repository = {
            patches = local.patches_dir
          }
          notebook_server = {
            install_dir = "/opt"
            patches = var.arcgis_notebook_server_patches
          }
          web_adaptor = {
            install_dir = "/opt"
            patches = var.arcgis_web_adaptor_patches
          }
        }
        run_list = [
          "recipe[arcgis-notebooks::install_patches]",
          "recipe[arcgis-enterprise::install_patches]"
        ]
      }))
    }

    command = "python -m az_run_chef -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -j ${var.deployment_id}-patches -v ${var.vault_name} -e 3600"
  }

  # Clean up
  provisioner "shell-local" {
    command = "python -m az_clean_up -s ${var.enterprise_id} -d ${var.deployment_id} -m ${local.machine_role} -f ${local.software_dir} -v ${var.vault_name}"
  }

  # Save the build artifacts metadata in packer-manifest.json file.
  # Note: New builds add new artifacts to packer-manifest.json file.
  post-processor "manifest" {
    output = "main-packer-manifest.json"
    strip_path = true
  }

  # Retrieve the image ID from main-packer-manifest.json manifest file and save it in key vault secrets.
  post-processor "shell-local" {
    command = "python -m publish_artifact -v ${var.vault_name} -s ${var.deployment_id}-vm-image-primary -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }

  post-processor "shell-local" {
    command = "python -m publish_artifact -v ${var.vault_name} -s ${var.deployment_id}-vm-image-node -f main-packer-manifest.json -r ${build.PackerRunUUID}"
  }

  # Save the source image information in key vault secret.
  post-processor "shell-local" {
    command = "az keyvault secret set --vault-name '${var.vault_name}' --name '${var.deployment_id}-os' --value '${var.os}'"
  }

  post-processor "shell-local" {
    command = "az keyvault secret set --vault-name '${var.vault_name}' --name '${var.deployment_id}-notebook-server-web-context' --value '${var.notebook_server_web_context}'"
  }
}
