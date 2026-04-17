/**
 * # Application Terraform Module for ArcGIS Notebook Server on Linux
 *
 * The Terraform module configures or upgrades applications for an ArcGIS Notebook Server deployment on the Linux platform.
 *
 * ![ArcGIS Notebook Server on Linux](arcgis-notebook-server-linux-application.png "ArcGIS Notebook Server on Linux")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all VMs of the deployment.
 *
 * If "is_upgrade" input variable is set to `true`, the module:
 *
 * * Copies the installation media for the ArcGIS Enterprise version specified by arcgis_version input variable to the private repository blob container
 * * Downloads the installation media from the private repository blob container to primary and node VMs
 * * Installs/upgrades ArcGIS Enterprise software on primary and node VMs
 * * Installs the software patches on primary and node VMs
 *
 * Then the module:
 *
 * * Copies the ArcGIS Notebook Server authorization file to the private repository blob container
 * * If specified, copies the root certificate files to the private repository blob container
 * * Downloads the ArcGIS Notebook Server authorization file from the private repository blob container to primary and node VMs
 * * If specified, downloads the root certificate files from the private repository blob container to primary and node VMs
 * * Creates the required directories in the NFS mount
 * * Configures ArcGIS Notebook Server on the primary VM
 * * Configures ArcGIS Notebook Server on the node VMs if any
 * * Federates ArcGIS Notebook Server with Portal for ArcGIS
 * * Deletes the downloaded setup archives, the extracted setups, and other temporary files from primary and node VMs
 *
 * ## Requirements
 *
 * The Azure resources for the deployment must be provisioned by Infrastructure Terraform module for ArcGIS Notebook Server on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.9 or later with [Azure SDK for Python](https://pypi.org/project/azure/) package must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * The working directory must be set to the arcgis-notebook-server-linux/application module path
 * * Azure credentials must be configured
 *
 * My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD.
 *
 * ## Key Vault Secrets
 *
 * The module reads the following Key Vault secrets: 
 *
 * | Secret Name                                      | Description |
 * |--------------------------------------------------|-------------|
 * | ${var.deployment_id}-backend-pfx-password        | Password for the backend PFX certificate |
 * | ${var.deployment_id}-deployment-fqdn             | Fully qualified domain name of the deployment |
 * | ${var.deployment_id}-notebook-server-web-context | ArcGIS Notebook Server web context | 
 * | ${var.deployment_id}-os                          | Operating system ID |
 * | ${var.deployment_id}-portal-url                  | Portal for ArcGIS URL | 
 * | ${var.deployment_id}-storage-account-name        | Config store storage account name |
 * | chef-client-url-${os}                            | Chef Client URL      |
 * | cookbooks-url                                    | Chef cookbooks URL |
 * | storage-account-key                              | Site storage account key |
 * | storage-account-name                             | Site storage account name |
 * | subnets                                          | VNet subnet IDs |
 * | vm-identity-client-id                            | VM identity client ID |
 * | vnet-id                                          | VNet ID |
 *
 * > The module also writes multiple attributes Key Vault secrets used to run Chef.
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

terraform {
  backend "azurerm" {
    key = "terraform/arcgis/notebook-server-linux/application.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_identity_client_id" {
  name         = "vm-identity-client-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "notebook_server_web_context" {
  name         = "${var.deployment_id}-notebook-server-web-context"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "portal_url" {
  name         = "${var.deployment_id}-portal-url"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "storage_account_name" {
  name         = "${var.deployment_id}-storage-account-name"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_image_os" {
  name         = "${var.deployment_id}-os"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "backend_pfx_password" {
  name         = "${var.deployment_id}-backend-pfx-password"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_virtual_machine" "primary" {
  name                = "primary"
  resource_group_name = "${var.site_id}-${var.deployment_id}-rg"
}

data "azurerm_resources" "nodes" {
  type = "Microsoft.Compute/virtualMachines"

  required_tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "node"
  }
}

data "azurerm_client_config" "current" {}

locals {
  manifest_file_path = "../manifests/arcgis-notebook-server-azure-files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  java_tarball       = local.manifest.arcgis.repository.metadata.java_tarball
  java_version       = local.manifest.arcgis.repository.metadata.java_version
  tomcat_tarball     = local.manifest.arcgis.repository.metadata.tomcat_tarball
  tomcat_version     = local.manifest.arcgis.repository.metadata.tomcat_version

  authorization_files_prefix = "software/authorization/${var.arcgis_version}"
  certificates_prefix        = "software/certificates/${var.deployment_id}"

  mount_point                 = "/mnt/fileserver"
  deployment_fqdn             = nonsensitive(data.azurerm_key_vault_secret.deployment_fqdn.value)
  notebook_server_web_context = nonsensitive(data.azurerm_key_vault_secret.notebook_server_web_context.value)
  portal_url                  = nonsensitive(data.azurerm_key_vault_secret.portal_url.value)
  primary_hostname            = data.azurerm_virtual_machine.primary.private_ip_address
  software_dir                = "/opt/software/setups/*"
  authorization_files_dir     = "/opt/software/authorization"
  certificates_dir            = "/opt/software/certificates"
  storage_account_name        = nonsensitive(data.azurerm_key_vault_secret.storage_account_name.value)

  keystore_file = "${local.certificates_dir}/${local.deployment_fqdn}.pfx"
  root_cert     = var.root_cert_file_path != null ? "${local.certificates_dir}/${basename(var.root_cert_file_path)}" : ""

  timestamp = formatdate("YYYYMMDDhhmm", timestamp())
  namespace = replace("${var.site_id}${var.deployment_id}", "/[^a-zA-Z0-9]/", "")
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

# Copy ArcGIS Notebook Server setup archives to the private repository blob storage if it's an upgrade deployment. 
module "az_copy_files" {
  count                         = var.is_upgrade ? 1 : 0
  source                        = "../../modules/az_copy_files"
  storage_account_blob_endpoint = module.site_core_info.storage_account_blob_endpoint
  container_name                = "repository"
  index_file                    = local.manifest_file_path
}

# Install Chef Client and Chef Cookbooks for ArcGIS on all VMs of the deployment
module "bootstrap_deployment" {
  source        = "../../modules/bootstrap"
  os            = nonsensitive(data.azurerm_key_vault_secret.vm_image_os.value)
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "node"]
}

# Download ArcGIS Notebook Server setup archives to primary and node EC2 instances
module "arcgis_notebook_server_files" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-files"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "node"]
  json_attributes = templatefile(
    local.manifest_file_path,
    {
      account_name   = module.site_core_info.storage_account_name
      container_name = "repository"
      client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
    }
  )
  execution_timeout = 1800
  depends_on = [
    module.bootstrap_deployment,
    module.az_copy_files
  ]
}

# Upgrade ArcGIS Notebook Server software on primary and node EC2 instances
module "arcgis_notebook_server_upgrade" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-upgrade"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "node"]
  json_attributes = jsonencode({
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
      version          = var.arcgis_version
      run_as_user      = var.run_as_user
      configure_autofs = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis_${local.tomcat_version}/webapps"
      }
      notebook_server = {
        install_dir                 = "/opt"
        install_system_requirements = true
        license_level               = var.license_level
        configure_autostart         = true
        wa_name                     = local.notebook_server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-tomcat::openjdk]",
      "recipe[esri-tomcat::install]",
      "recipe[arcgis-notebooks::install_server]",
      "recipe[arcgis-notebooks::install_server_wa]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_notebook_server_files
  ]
}

# Patch ArcGIS Notebook Server software on primary and node EC2 instances
module "arcgis_notebook_server_patch" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-patch"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      repository = {
        patches = local.patches_dir
      }
      notebook_server = {
        install_dir = "/opt"
        patches     = var.arcgis_notebook_server_patches
      }
      web_adaptor = {
        install_dir = "/opt"
        patches     = var.arcgis_web_adaptor_patches
      }
    }
    run_list = [
      "recipe[arcgis-notebooks::install_patches]",
      "recipe[arcgis-enterprise::install_patches]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_notebook_server_upgrade
  ]
}

# Configure fileserver 
module "arcgis_notebook_server_fileserver" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-fileserver"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      fileserver = {
        directories = [
          "${local.mount_point}/gisdata/notebookserver"
        ]
        shares = [
        ]
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::fileserver]"
    ]
  })
  depends_on = [
    module.bootstrap_deployment,
    module.arcgis_notebook_server_patch
  ]
}

# Upload ArcGIS Server authorization file to the private repository blob container
resource "azurerm_storage_blob" "server_authorization_file" {
  name                   = "${local.authorization_files_prefix}/${basename(var.notebook_server_authorization_file_path)}"
  storage_account_name   = module.site_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.notebook_server_authorization_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.notebook_server_authorization_file_path))
}

# If specified, upload root certificate file to the private repository blob container
resource "azurerm_storage_blob" "root_cert_file" {
  count                  = var.root_cert_file_path != null ? 1 : 0
  name                   = "${local.certificates_prefix}/${basename(var.root_cert_file_path)}"
  storage_account_name   = module.site_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.root_cert_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.root_cert_file_path))
}

# Download ArcGIS Notebook Server authorization file to primary and node EC2 instances
module "authorization_files" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-authorization-files"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.authorization_files_dir
        azure_cli = {
          install_dir = "/usr"
        }
        server = {
          account_name   = module.site_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${basename(var.notebook_server_authorization_file_path)}" = {
            subfolder = local.authorization_files_prefix
          }
        }
      }
    }
    run_list = [
      "recipe[arcgis-repository::azure_files]"
    ]
  })
  depends_on = [
    module.arcgis_notebook_server_fileserver,
    azurerm_storage_blob.server_authorization_file
  ]
}

# Download keystore file to primary and node EC2 instances
module "keystore_file" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-keystore-file"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        azure_cli = {
          install_dir = "/usr"
        }
        server = {
          account_name   = module.site_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${local.deployment_fqdn}.pfx" = {
            subfolder = local.certificates_prefix
          }
        }
      }
    }
    run_list = [
      "recipe[arcgis-repository::azure_files]"
    ]
  })
  depends_on = [
    module.authorization_files
  ]
}

# Download root certificate file to primary and node EC2 instances
module "root_cert" {
  count                  = var.root_cert_file_path != null ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-root-cert"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "node"]
  json_attributes = jsonencode({
    arcgis = {
      version = var.arcgis_version
      repository = {
        local_archives = local.certificates_dir
        azure_cli = {
          install_dir = "/usr"
        }
        server = {
          account_name   = module.site_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${basename(var.root_cert_file_path)}" = {
            subfolder = local.certificates_prefix
          }
        }
      }
    }
    run_list = [
      "recipe[arcgis-repository::azure_files]"
    ]
  })
  depends_on = [
    module.authorization_files,
    module.keystore_file,
    azurerm_storage_blob.root_cert_file
  ]
}

# Configure ArcGIS Notebook Server on primary EC2 instance
module "arcgis_notebook_server_primary" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-primary"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = local.deployment_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = data.azurerm_key_vault_secret.backend_pfx_password.value
    }
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis/webapps"
      }
      notebook_server = {
        url                   = "https://${local.primary_hostname}:11443/arcgis"
        wa_url                = "https://${local.primary_hostname}/${local.notebook_server_web_context}"
        install_dir           = "/opt"
        admin_username        = var.admin_username
        admin_password        = var.admin_password
        authorization_file    = "${local.authorization_files_dir}/${basename(var.notebook_server_authorization_file_path)}"
        authorization_options = var.notebook_server_authorization_options
        license_level         = var.license_level
        keystore_file         = local.keystore_file
        keystore_password     = data.azurerm_key_vault_secret.backend_pfx_password.value
        cert_alias            = "servercert"
        root_cert             = local.root_cert
        root_cert_alias       = "rootcert"
        directories_root      = "${local.mount_point}/gisdata/notebookserver"
        workspace             = "${local.mount_point}/gisdata/notebookserver/directories/arcgisworkspace"
        log_dir               = "${local.mount_point}/gisdata/notebookserver/logs"
        log_level             = var.log_level
        config_store_type     = var.config_store_type
        config_store_connection_string = (var.config_store_type == "AZURE" ?
          "NAMESPACE=${local.namespace};AccountName=${local.storage_account_name};CredentialType=UserAssignedIdentity;ManagedIdentityClientId=${data.azurerm_key_vault_secret.vm_identity_client_id.value}" :
        "${local.mount_point}/gisdata/notebookserver/config-store")
        config_store_connection_secret = ""
        install_system_requirements    = true
        wa_name                        = local.notebook_server_web_context
        services_dir_enabled           = true
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[esri-tomcat]",
      "recipe[arcgis-notebooks::server]",
      "recipe[arcgis-notebooks::restart_docker]",
      "recipe[arcgis-notebooks::server_wa]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_notebook_server_fileserver,
    module.authorization_files,
    module.keystore_file,
    module.root_cert
  ]
}

# Configure ArcGIS Notebook Server on node Azure VMs if any
module "arcgis_notebook_server_node" {
  count                  = length(data.azurerm_resources.nodes.resources) > 0 ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-node"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["node"]
  json_attributes = jsonencode({
    tomcat = {
      domain_name       = local.deployment_fqdn
      install_path      = "/opt/tomcat_arcgis"
      keystore_file     = local.keystore_file
      keystore_password = data.azurerm_key_vault_secret.backend_pfx_password.value
    }
    arcgis = {
      version     = var.arcgis_version
      run_as_user = var.run_as_user
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      web_server = {
        webapp_dir = "/opt/tomcat_arcgis/webapps"
      }
      notebook_server = {
        install_dir                 = "/opt"
        primary_server_url          = "https://${local.primary_hostname}:11443/arcgis"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        license_level               = var.license_level
        keystore_file               = local.keystore_file
        keystore_password           = data.azurerm_key_vault_secret.backend_pfx_password.value
        cert_alias                  = "servercert"
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        log_dir                     = "${local.mount_point}/gisdata/notebookserver/logs"
        authorization_file          = "${local.authorization_files_dir}/${basename(var.notebook_server_authorization_file_path)}"
        authorization_options       = var.notebook_server_authorization_options
        install_system_requirements = true
        wa_name                     = local.notebook_server_web_context
      }
      web_adaptor = {
        install_dir = "/opt"
      }
    }
    run_list = [
      "recipe[esri-tomcat]",
      "recipe[arcgis-notebooks::server_node]",
      "recipe[arcgis-notebooks::restart_docker]",
      "recipe[arcgis-notebooks::server_wa]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_notebook_server_primary
  ]
}

# Federate ArcGIS Notebook Server with Portal for ArcGIS
module "arcgis_notebook_server_federation" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-federation"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      portal = {
        private_url     = local.portal_url
        admin_username  = var.portal_username
        admin_password  = var.portal_password
        root_cert       = ""
        root_cert_alias = "notebookserver"
      }
      notebook_server = {
        web_context_url = "https://${local.deployment_fqdn}/${local.notebook_server_web_context}"
        private_url     = "https://${local.deployment_fqdn}/${local.notebook_server_web_context}"
        admin_username  = var.admin_username
        admin_password  = var.admin_password
      }
    }
    run_list = [
      "recipe[arcgis-notebooks::federation]"
    ]
  })
  execution_timeout = 3600
  depends_on = [
    module.arcgis_notebook_server_primary,
    module.arcgis_notebook_server_node
  ]
}

# Delete the downloaded setup archives, the extracted setups, and other 
# temporary files from primary and node EC2 instances.
module "clean_up" {
  source                = "../../modules/clean_up"
  site_id               = var.site_id
  deployment_id         = var.deployment_id
  machine_roles         = ["primary", "node"]
  directories           = [local.software_dir]
  uninstall_chef_client = false
  depends_on = [
    module.arcgis_notebook_server_federation
  ]
}
