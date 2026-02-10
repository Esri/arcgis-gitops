/**
 * # Application Terraform Module for Base ArcGIS Enterprise on Windows
 *
 * This Terraform module configures or upgrades applications of base ArcGIS Enterprise deployment on the Windows platform.
 *
 * ![Base ArcGIS Enterprise on Windows](enterprise-base-windows-azure-application.png "Base ArcGIS Enterprise on Windows")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all VMs of the deployment.
 *
 * If "is_upgrade" input variable is set to true, the module:
 *
 * * Un-registers the ArcGIS Server Web Adaptor on the standby VM
 * * Copies the installation media for the ArcGIS Enterprise version specified by arcgis_version input variable to the private repository blob container
 * * Downloads the installation media from the private repository blob container to the primary and standby VMs
 * * Installs or upgrades ArcGIS Enterprise software on the primary and standby VMs
 * * Installs software patches on the primary and standby VMs
 *
 * Then the module:
 *
 * * Copies the ArcGIS Server and Portal for ArcGIS authorization files to the private repository blob container
 * * Copies the keystore and, if specified, root certificate files to the private repository blob container
 * * Downloads the ArcGIS Server and Portal for ArcGIS authorization files from the private repository blob container to primary and standby VMs
 * * Downloads the keystore and root certificate files from the private repository blob container to the primary and standby VMs
 * * Creates the required network shares and directories in the primary VM
 * * Configures base ArcGIS Enterprise on the primary VM
 * * Configures base ArcGIS Enterprise on the standby VM
 * * Deletes the downloaded setup archives, the extracted setups, and other temporary files from the primary and standby VMs
 *
 * Starting with ArcGIS Enterprise 12.0, if the config_store_type input variable is set to AZURE,
 * the module configures ArcGIS Server to store server directories in an Azure Blob container and 
 * the configuration store in a Cosmos DB database, rather than on a file share.
 *
 * ## Requirements
 *
 * The Azure resources for the deployment must be provisioned by Infrastructure terraform module for base ArcGIS Enterprise on Windows.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.9 or later must be installed
 * * azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured using "az login" CLI command
 *
 * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.
 *
 * ## Key Vault Secrets
 *
 * The module reads the following Key Vault secrets:
 *
 * | Key Vault secret name | Description |
 * |--------------------|-------------|
 * | subnets | VNet subnets IDs |
 * | vnet-id | VNet ID |
 * | storage-account-key | Site's storage account key |
 * | storage-account-name | Site's storage account name |
 * | ${var.deployment_id}-deployment-fqdn | Deployment's FQDN |
 * | ${var.deployment_id}-storage-account-name | Deployment's storage account name |
 * | vm-identity-client-id | VM identity client ID |
 *
 * The module creates the following Key Vault secrets:
 * | Key Vault secret name | Description |
 * |--------------------|-------------|
 * | ${var.deployment_id}-deployment-url | Deployment's URL |
 *
 * > Note that the module also uses Key Vault secrets to pass JSON attributes
 *   for Chef Client runs to the VMs. These secrets are deleted at the end of the runs.
 */

# Copyright 2025-2026 Esri
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
    key = "terraform/arcgis/enterprise-base-windows/application.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "storage_account_name" {
  name         = "${var.deployment_id}-storage-account-name"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_identity_client_id" {
  name         = "vm-identity-client-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_virtual_machine" "primary" {
  name                = "primary"
  resource_group_name = "${var.site_id}-${var.deployment_id}-rg"
}

data "azurerm_resources" "standby" {
  type = "Microsoft.Compute/virtualMachines"

  required_tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "standby"
  }
}

locals {
  manifest_file_path = "../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches
  dotnet_setup       = local.manifest.arcgis.repository.metadata.dotnet_setup
  web_deploy_setup   = local.manifest.arcgis.repository.metadata.web_deploy_setup

  authorization_files_prefix = "software/authorization/${var.deployment_id}/${var.arcgis_version}"
  certificates_prefix        = "software/certificates/${var.deployment_id}"

  deployment_fqdn  = nonsensitive(data.azurerm_key_vault_secret.deployment_fqdn.value)
  primary_hostname = "primary.${var.deployment_id}.${var.site_id}.internal"
  standby_hostname = "standby.${var.deployment_id}.${var.site_id}.internal"

  software_dir            = "C:\\Software\\*"
  authorization_files_dir = "C:\\Software\\AuthorizationFiles"
  certificates_dir        = "C:\\Software\\Certificates"

  keystore_file = var.keystore_file_path != null ? "${local.certificates_dir}\\${basename(var.keystore_file_path)}" : "C:\\chef\\keystore.pfx"
  root_cert     = var.root_cert_file_path != null ? "${local.certificates_dir}\\${basename(var.root_cert_file_path)}" : ""

  timestamp = formatdate("YYYYMMDDHHmmss", timestamp())

  storage_account_name          = data.azurerm_key_vault_secret.storage_account_name.value
  storage_account_blob_endpoint = "https://${data.azurerm_key_vault_secret.storage_account_name.value}.blob.core.windows.net"
  cosmos_db_account_name        = local.storage_account_name
  service_bus_namespace         = local.storage_account_name
   
  is_ha = length(data.azurerm_resources.standby.resources) > 0

  # See "Azure user-assigned identity example" in cloudConfigJson parameter description at
  # https://developers.arcgis.com/rest/enterprise-administration/server/createsite/
  cloud_config = var.config_store_type == "AZURE" ? jsonencode([{
    name = "AZURE"
    namespace = "${var.site_id}-${var.deployment_id}"
    credential = {
      type = "USER-ASSIGNED-IDENTITY"
      secret = {
        managedIdentityClientId = data.azurerm_key_vault_secret.vm_identity_client_id.value
      }
    }    
    cloudServices = [{
      name  = "Azure Blob Store"
      type  = "objectStore"
      usage = "DEFAULT"
      connection = {
        containerName = "object-store"
        rootDir = "arcgis"
        accountEndpointUrl = "https://${local.storage_account_name}.blob.core.windows.net"
      }
      category = "storage"
    },
    {
      name = "Azure Cosmos DB"
      type = "tableStore"
      connection = {
        subscriptionId = data.azurerm_client_config.current.subscription_id
        resourceGroupName = "${var.site_id}-${var.deployment_id}-rg"
        accountEndpointUrl = "https://${local.cosmos_db_account_name}.documents.azure.com"
        databaseId = "config-store"
        cosmosDBConnectionMode = "Gateway"
      }
      category = "storage"
    },
    {
      name = "Azure Service Bus"
      type = "queueService"
      connection = {
        serviceBusEndpointUrl = "sb://${local.service_bus_namespace}.servicebus.windows.net"
      }
      category = "queue"
    }]
  }]) : null

  data_items = var.config_store_type == "AZURE" ? [] : [{
    path     = "/cloudStores/cloudObjectStore"
    type     = "objectStore"
    provider = "azure"
    info = {
      isManaged     = true
      systemManaged = false
      isManagedData = true
      purposes      = ["feature-tile", "scene"]
      connectionString = jsonencode({
        accountName             = local.storage_account_name
        credentialType          = "userAssignedIdentity"
        managedIdentityClientId = data.azurerm_key_vault_secret.vm_identity_client_id.value
      })
      objectStore       = "object-store"
      encryptAttributes = ["info.connectionString"]
    }
  }]
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

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
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "standby"]
  os            = var.os
}

# Download base ArcGIS Enterprise setup archives to primary and standby VMs
module "arcgis_enterprise_files" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-files"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
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

# If it's an upgrade, unregister ArcGIS Server's Web Adaptor on standby VM
module "begin_upgrade_standby" {
  count                  = var.is_upgrade && local.is_ha ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-begin-upgrade-standby"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      server = {
        admin_username = var.admin_username
        admin_password = var.admin_password
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::unregister_server_wa]"
    ]
  })
  execution_timeout = 600
  depends_on = [
    module.arcgis_enterprise_files
  ]
}

# Upgrade base ArcGIS Enterprise software on primary and standby VMs
module "arcgis_enterprise_upgrade" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-upgrade"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                    = var.arcgis_version
      run_as_user                = var.run_as_user
      run_as_password            = var.run_as_password
      configure_windows_firewall = true
      configure_cloud_settings   = false
      repository = {
        archives = local.archives_dir
        setups   = "C:\\Software\\Setups"
      }
      server = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\Server"
        install_system_requirements = true
        wa_name                     = var.server_web_context
      }
      web_adaptor = {
        install_system_requirements = true
        dotnet_setup_path           = "${local.archives_dir}\\${local.dotnet_setup}"
        web_deploy_setup_path       = "${local.archives_dir}\\${local.web_deploy_setup}"
        admin_access                = true
        reindex_portal_content      = false
      }
      data_store = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\DataStore"
        setup_options               = "ADDLOCAL=relational"
        data_dir                    = "C:\\arcgisdatastore"
        install_system_requirements = true
        preferredidentifier         = "hostname"
      }
      portal = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\Portal"
        install_system_requirements = true
        data_dir                    = "C:\\arcgisportal"
        wa_name                     = var.portal_web_context
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-iis::install]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::start_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::install_portal_wa]",
      "recipe[arcgis-enterprise::install_server]",
      "recipe[arcgis-enterprise::start_server]",
      "recipe[arcgis-enterprise::install_server_wa]",
      "recipe[arcgis-enterprise::install_datastore]",
      "recipe[arcgis-enterprise::start_datastore]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_enterprise_files,
    module.begin_upgrade_standby
  ]
}

# Patch base ArcGIS Enterprise software on primary and standby VMs
module "arcgis_enterprise_patch" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-patch"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
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
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_enterprise_upgrade
  ]
}

# Configure fileserver for ArcGIS Server directories and WebGIS DR staging location.
# Create the required network shares and directories in the primary VM.
# Allow loopback to FILESERVER hostname.
module "arcgis_enterprise_fileserver" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-fileserver"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      run_as_password          = var.run_as_password
      configure_cloud_settings = false
      fileserver = {
        directories = [
          "C:\\data\\arcgisserver",
          "C:\\data\\arcgisbackup\\webgisdr"
        ]
        shares = [
          "C:\\data\\arcgisserver",
          "C:\\data\\arcgisbackup"
        ]
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::disable_loopback_check]",
      "recipe[arcgis-enterprise::fileserver]"
    ]
  })
  depends_on = [
    module.bootstrap_deployment,
    module.arcgis_enterprise_patch
  ]
}


# Upload ArcGIS Server authorization file to the private repository blob container
resource "azurerm_storage_blob" "server_authorization_file" {
  name                   = "${local.authorization_files_prefix}/${basename(var.server_authorization_file_path)}"
  storage_account_name   = module.site_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.server_authorization_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.server_authorization_file_path))
}

# Upload Portal for ArcGIS authorization file to the private repository blob container
resource "azurerm_storage_blob" "portal_authorization_file" {
  name                   = "${local.authorization_files_prefix}/${basename(var.portal_authorization_file_path)}"
  storage_account_name   = module.site_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.portal_authorization_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.portal_authorization_file_path))
}

# If specified, upload keystore file to the private repository blob container
resource "azurerm_storage_blob" "keystore_file" {
  count                  = var.keystore_file_path != null ? 1 : 0
  name                   = "${local.certificates_prefix}/${basename(var.keystore_file_path)}"
  storage_account_name   = module.site_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.keystore_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.keystore_file_path))
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

# Download ArcGIS Server authorization file to primary and standby VMs
module "authorization_files" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-authorization-files"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.authorization_files_dir
        server = {
          account_name   = module.site_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${basename(var.server_authorization_file_path)}" = {
            subfolder = local.authorization_files_prefix
          }
          "${basename(var.portal_authorization_file_path)}" = {
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
    module.arcgis_enterprise_fileserver,
    azurerm_storage_blob.server_authorization_file,
    azurerm_storage_blob.portal_authorization_file
  ]
}

# Download keystore file to primary and standby VMs
module "keystore" {
  count                  = var.keystore_file_path != null ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-keystore-file"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.certificates_dir
        server = {
          account_name   = module.site_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${basename(var.keystore_file_path)}" = {
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
    azurerm_storage_blob.keystore_file
  ]
}

# Download root certificate file to primary and standby VMs
module "root_cert" {
  count                  = var.root_cert_file_path != null ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-root-cert"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.certificates_dir
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
    azurerm_storage_blob.keystore_file,
    azurerm_storage_blob.root_cert_file
  ]
}

# Configure base ArcGIS Enterprise on primary VM
module "arcgis_enterprise_primary" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-primary"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version                    = var.arcgis_version
      run_as_user                = var.run_as_user
      run_as_password            = var.run_as_password
      configure_windows_firewall = true
      configure_cloud_settings   = false
      # Though local.primary_hostname resolves to the instance's private IP by the Route53 private hosted zone,
      # the loopback for primary_hostname is required to prevent the reverse IP lookup of the Portal's 
      # Apache Ignite using the machine hostname for the node hostname instead of primary_hostname.
      # without activating the deployment (routing deployment_fqdn to the deployment's ALB).
      hosts = {
        "${local.primary_hostname} FILESERVER" = ""
      }
      repository = {
        archives = local.archives_dir
        setups   = "C:\\Software\\Setups"
      }
      iis = {
        domain_name           = local.deployment_fqdn
        keystore_file         = local.keystore_file
        keystore_password     = var.keystore_file_password
        replace_https_binding = true
      }
      server = {
        url                         = "https://${local.primary_hostname}:6443/arcgis"
        wa_url                      = "https://${local.primary_hostname}/${var.server_web_context}"
        install_dir                 = "C:\\Program Files\\ArcGIS\\Server"
        install_system_requirements = true
        private_url                 = "https://${local.deployment_fqdn}/${var.server_web_context}"
        web_context_url             = "https://${local.deployment_fqdn}/${var.server_web_context}"
        hostname                    = local.primary_hostname
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        authorization_file          = "${local.authorization_files_dir}\\${basename(var.server_authorization_file_path)}"
        authorization_options       = var.server_authorization_options
        keystore_file               = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        directories_root            = "\\\\FILESERVER\\arcgisserver"
        log_dir                     = "C:\\arcgisserver\\logs"
        log_level                   = var.log_level
        config_store_type           = var.config_store_type
        # If cloud_config is set, config_store_connection_string is ignored
        config_store_connection_string = "\\\\FILESERVER\\arcgisserver\\config-store"
        cloud_config                = local.cloud_config
        wa_name                     = var.server_web_context
        services_dir_enabled        = true
        callback_functions_enabled  = true
        system_properties = {
          WebContextURL = "https://${local.deployment_fqdn}/${var.server_web_context}"
        }
        # Configure the managed object store in blob container
        data_items = local.data_items
      }
      data_store = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\DataStore"
        setup_options               = "ADDLOCAL=relational"
        install_system_requirements = true
        data_dir                    = "C:\\arcgisdatastore"
        preferredidentifier         = "hostname"
        hostidentifier              = local.primary_hostname
        types                       = "relational"
        relational = {
          enablessl               = true
          disk_threshold_readonly = 5120
          max_connections         = 150
          # Point-in-time recovery (PITR) must be enabled in relational ArcGIS Data Store for WebGISDR tool to work in "incremental" backup-restore mode.
          pitr        = "enable"
          backup_type = "s3" # Use "s3" to configure backup in Azure blob container
          # Configure the data store backup location in blob container
          backup_location = "type=azure;location=datastore-backups/${var.deployment_id}/relational;name=re_default;username=${module.site_core_info.storage_account_name};password=${module.site_core_info.storage_account_key}"
        }
      }
      portal = {
        url                         = "https://${local.primary_hostname}:7443/arcgis"
        wa_url                      = "https://${local.primary_hostname}/${var.portal_web_context}"
        preferredidentifier         = "hostname"
        hostname                    = local.primary_hostname
        hostidentifier              = local.primary_hostname
        install_dir                 = "C:\\Program Files\\ArcGIS\\Portal"
        install_system_requirements = true
        private_url                 = "https://${local.deployment_fqdn}/${var.portal_web_context}"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        admin_email                 = var.admin_email
        admin_full_name             = var.admin_full_name
        admin_description           = var.admin_description
        security_question_index     = var.security_question_index
        security_question_answer    = var.security_question_answer
        data_dir                    = "C:\\arcgisportal"
        log_dir                     = "C:\\arcgisportal\\logs"
        log_level                   = var.log_level
        # Configure the portal content in blob container
        # See: https://enterprise.arcgis.com/en/portal/latest/administer/linux/changing-the-portal-content-directory.htm
        content_store_type     = "cloudStore"
        content_store_provider = "Azure"
        content_store_connection_string = {
          accountName             = local.storage_account_name
          accountEndpoint         = "blob.core.windows.net"
          credentialType          = "userAssignedIdentity"
          managedIdentityClientId = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        object_store         = "${local.storage_account_blob_endpoint}/portal-content"
        authorization_file   = "${local.authorization_files_dir}\\${basename(var.portal_authorization_file_path)}"
        user_license_type_id = var.portal_user_license_type_id
        keystore_file        = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password    = var.keystore_file_password
        cert_alias           = "portalcert"
        root_cert            = local.root_cert
        root_cert_alias      = "rootcert"
        wa_name              = var.portal_web_context
        system_properties = {
          privatePortalURL = "https://${local.deployment_fqdn}:7443/arcgis"
          WebContextURL    = "https://${local.deployment_fqdn}/${var.portal_web_context}"
        }
      }
      web_adaptor = {
        install_system_requirements = true
        dotnet_setup_path           = null
        web_deploy_setup_path       = null
        admin_access                = true
        reindex_portal_content      = false
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[esri-iis]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal]",
      "recipe[arcgis-enterprise::portal_wa]",
      "recipe[arcgis-enterprise::server]",
      "recipe[arcgis-enterprise::server_wa]",
      "recipe[arcgis-enterprise::datastore]",
      "recipe[arcgis-enterprise::server_data_items]",
      "recipe[arcgis-enterprise::federation]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.authorization_files,
    module.keystore,
    module.root_cert
  ]
}

# Configure base ArcGIS Enterprise on standby VM
module "arcgis_enterprise_standby" {
  count                  = local.is_ha ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-standby"
  site_id                = var.site_id
  deployment_id          = var.deployment_id
  machine_roles          = ["standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                    = var.arcgis_version
      run_as_user                = var.run_as_user
      run_as_password            = var.run_as_password
      configure_windows_firewall = true
      configure_cloud_settings   = false
      hosts = {
        "${local.standby_hostname}" = ""
        "FILESERVER"                = "${data.azurerm_virtual_machine.primary.private_ip_address}"
      }
      repository = {
        archives = local.archives_dir
        setups   = "C:\\Software\\Setups"
      }
      iis = {
        domain_name           = local.deployment_fqdn
        keystore_file         = local.keystore_file
        keystore_password     = var.keystore_file_password
        replace_https_binding = true
      }
      server = {
        url                         = "https://${local.standby_hostname}:6443/arcgis"
        wa_url                      = "https://${local.standby_hostname}/${var.server_web_context}"
        hostname                    = local.standby_hostname
        install_dir                 = "C:\\Program Files\\ArcGIS\\Server"
        install_system_requirements = true
        primary_server_url          = "https://${local.primary_hostname}:6443/arcgis"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        authorization_file          = "${local.authorization_files_dir}\\${basename(var.server_authorization_file_path)}"
        authorization_options       = var.server_authorization_options
        keystore_file               = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password           = var.keystore_file_password
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        log_dir                     = "C:\\arcgisserver\\logs"
        wa_name                     = var.server_web_context
      }
      data_store = {
        install_dir                 = "C:\\Program Files\\ArcGIS\\DataStore"
        setup_options               = "ADDLOCAL=relational"
        install_system_requirements = true
        data_dir                    = "C:\\arcgisdatastore"
        preferredidentifier         = "hostname"
        hostidentifier              = local.standby_hostname
        types                       = "relational"
      }
      portal = {
        url                         = "https://${local.standby_hostname}:7443/arcgis"
        wa_url                      = "https://${local.standby_hostname}/${var.portal_web_context}"
        preferredidentifier         = "hostname"
        hostname                    = local.standby_hostname
        hostidentifier              = local.standby_hostname
        install_dir                 = "C:\\Program Files\\ArcGIS\\Portal"
        install_system_requirements = true
        primary_machine_url         = "https://${local.primary_hostname}:7443"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        keystore_file               = var.keystore_file_path != null ? local.keystore_file : ""
        keystore_password           = var.keystore_file_password
        cert_alias                   = "portalcert"
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        data_dir                    = "C:\\arcgisportal"
        log_dir                     = "C:\\arcgisportal\\logs"
        wa_name                     = var.portal_web_context
      }
      web_adaptor = {
        install_system_requirements = true
        dotnet_setup_path           = null
        web_deploy_setup_path       = null
        admin_access                = true
        reindex_portal_content      = false
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::disable_loopback_check]",
      "recipe[esri-iis]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal_standby]",
      "recipe[arcgis-enterprise::portal_wa]",
      "recipe[arcgis-enterprise::server_node]",
      "recipe[arcgis-enterprise::server_wa]",
      "recipe[arcgis-enterprise::datastore_standby]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.arcgis_enterprise_primary
  ]
}

resource "azurerm_key_vault_secret" "deployment_url" {
  name         = "${var.deployment_id}-deployment-url"
  value        = "https://${data.azurerm_key_vault_secret.deployment_fqdn.value}/${var.portal_web_context}"
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Delete the downloaded setup archives, the extracted setups, and other 
# temporary files from primary and standby VMs.
module "clean_up" {
  source                = "../../modules/clean_up"
  site_id               = var.site_id
  deployment_id         = var.deployment_id
  machine_roles         = ["primary", "standby"]
  directories           = [local.software_dir]
  uninstall_chef_client = false
  depends_on = [
    module.arcgis_enterprise_primary,
    module.arcgis_enterprise_standby
  ]
}
