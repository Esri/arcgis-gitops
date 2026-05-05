/**
 * # Application Terraform Module for Base ArcGIS Enterprise on Linux
 *
 * This Terraform module configures or upgrades applications for a base ArcGIS Enterprise deployment on the Linux platform.
 *
 * ![Base ArcGIS Enterprise on Linux](enterprise-base-linux-azure-application.png "Base ArcGIS Enterprise on Linux")
 *
 * First, the module bootstraps the deployment by installing Chef Client and Chef Cookbooks for ArcGIS on all VMs of the deployment.
 *
 * If "is_upgrade" input variable is set to true, the module:
 *
 * * Copies the installation media for the ArcGIS Enterprise version specified by arcgis_version input variable to the private repository blob container
 * * Downloads the installation media from the private repository blob container to the primary and standby VMs
 * * Installs or upgrades ArcGIS Enterprise software on the primary and standby VMs
 * * Installs software patches on the primary and standby VMs
 *
 * Then the module:
 *
 * * Copies the ArcGIS Server and Portal for ArcGIS authorization files to the private repository blob container
 * * If specified, copies the root certificate file to the private repository blob container
 * * Downloads the ArcGIS Server and Portal for ArcGIS authorization files from the private repository blob container to primary and standby VMs
 * * Downloads the keystore and root certificate files from the private repository blob container to the primary and standby VMs
 * * Creates the required directories in the NFS mount
 * * Configures base ArcGIS Enterprise on the primary VM
 * * Configures base ArcGIS Enterprise on the standby VM
 * * Deletes the downloaded setup archives, the extracted setups, and other temporary files from the primary and standby VMs
 *
 * Starting with ArcGIS Enterprise 12.0, if the config_store_type input variable is set to AZURE,
 * the module configures ArcGIS Server to store server directories in an Azure Blob container and 
 * the configuration store in a Cosmos DB database, rather than on the NFS file share.
 *
 * ## Requirements
 *
 * The Azure resources for the deployment must be provisioned by Infrastructure Terraform module for base ArcGIS Enterprise on Linux.
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.9 or later must be installed
 * * azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured using "az login" CLI command
 *
 * ## Key Vault Secrets
 *
 * The module reads the following Key Vault secrets:
 *
 * | Key Vault secret name                     | Description |
 * |-------------------------------------------|-------------|
 * | subnets                                   | VNet subnet IDs |
 * | vnet-id                                   | VNet ID |
 * | storage-account-key                       | Enterprise's storage account key |
 * | storage-account-name                      | Enterprise's storage account name |
 * | vm-identity-client-id                     | VM identity client ID |
 * | ${var.deployment_id}-backend-pfx-password | Password for the backend PFX certificate |
 * | ${var.deployment_id}-ingress-fqdn         | Ingress FQDN |
 * | ${var.deployment_id}-portal-web-context   | Portal for ArcGIS web context |
 * | ${var.deployment_id}-server-web-context   | ArcGIS Server web context |
 * | ${var.deployment_id}-storage-account-name | Deployment's storage account name |
 * | ${var.deployment_id}-os                   | Operating system ID |
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
    key = "terraform/arcgis/enterprise-base-linux/application.tfstate"
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

data "azurerm_key_vault_secret" "ingress_fqdn" {
  name         = "${var.deployment_id}-ingress-fqdn"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_key_vault_secret" "storage_account_name" {
  name         = "${var.deployment_id}-storage-account-name"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_identity_client_id" {
  name         = "vm-identity-client-id"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_key_vault_secret" "portal_web_context" {
  name         = "${var.deployment_id}-portal-web-context"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_key_vault_secret" "server_web_context" {
  name         = "${var.deployment_id}-server-web-context"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_key_vault_secret" "backend_pfx_password" {
  name         = "${var.deployment_id}-backend-pfx-password"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_image_os" {
  name         = "${var.deployment_id}-os"
  key_vault_id = module.enterprise_core_info.vault_id
}

data "azurerm_virtual_machine" "primary" {
  name                = "primary"
  resource_group_name = "${var.enterprise_id}-${var.deployment_id}-rg"
}

data "azurerm_resources" "standby" {
  type = "Microsoft.Compute/virtualMachines"

  required_tags = {
    ArcGISEnterpriseID = var.enterprise_id
    ArcGISDeploymentID = var.deployment_id
    ArcGISRole         = "standby"
  }
}

data "azurerm_virtual_machine" "standby" {
  count               = length(data.azurerm_resources.standby.resources) > 0 ? 1 : 0
  name                = data.azurerm_resources.standby.resources[0].name
  resource_group_name = "${var.enterprise_id}-${var.deployment_id}-rg"
}

locals {
  portal_web_context = nonsensitive(data.azurerm_key_vault_secret.portal_web_context.value)
  server_web_context = nonsensitive(data.azurerm_key_vault_secret.server_web_context.value)

  manifest_file_path = "../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json"
  manifest           = jsondecode(file(local.manifest_file_path))
  archives_dir       = local.manifest.arcgis.repository.local_archives
  patches_dir        = local.manifest.arcgis.repository.local_patches

  authorization_files_prefix = "software/authorization/${var.deployment_id}/${var.arcgis_version}"
  certificates_prefix        = "software/certificates/${var.deployment_id}"

  ingress_fqdn  = nonsensitive(data.azurerm_key_vault_secret.ingress_fqdn.value)
  primary_hostname = data.azurerm_virtual_machine.primary.private_ip_address
  standby_hostname = length(data.azurerm_resources.standby.resources) > 0 ? data.azurerm_virtual_machine.standby[0].private_ip_address : ""

  mount_point             = "/mnt/fileserver"
  software_dir            = "/opt/software/*"
  authorization_files_dir = "/opt/software/authorization"
  certificates_dir        = "/opt/software/certificates"

  primary_backend_cert  = "${local.primary_hostname}.pfx"
  primary_keystore_file = "${local.certificates_dir}/${local.primary_backend_cert}"
  standby_backend_cert  = length(data.azurerm_resources.standby.resources) > 0 ? "${local.standby_hostname}.pfx" : ""
  standby_keystore_file = length(data.azurerm_resources.standby.resources) > 0 ? "${local.certificates_dir}/${local.standby_backend_cert}" : ""
  root_cert             = var.root_cert_file_path != null ? "${local.certificates_dir}/${basename(var.root_cert_file_path)}" : ""

  storage_account_name          = data.azurerm_key_vault_secret.storage_account_name.value
  storage_account_blob_endpoint = "https://${data.azurerm_key_vault_secret.storage_account_name.value}.blob.core.windows.net"
  cosmos_db_account_name        = local.storage_account_name
  service_bus_namespace         = local.storage_account_name

  is_ha = length(data.azurerm_resources.standby.resources) > 0

  cloud_config = var.config_store_type == "AZURE" ? jsonencode([{
    name      = "AZURE"
    namespace = "${var.enterprise_id}-${var.deployment_id}"
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
        containerName      = "object-store"
        rootDir            = "arcgis"
        accountEndpointUrl = "https://${local.storage_account_name}.blob.core.windows.net"
      }
      category = "storage"
      },
      {
        name = "Azure Cosmos DB"
        type = "tableStore"
        connection = {
          subscriptionId         = data.azurerm_client_config.current.subscription_id
          resourceGroupName      = "${var.enterprise_id}-${var.deployment_id}-rg"
          accountEndpointUrl     = "https://${local.cosmos_db_account_name}.documents.azure.com"
          databaseId             = "config-store"
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

module "enterprise_core_info" {
  source        = "../../modules/enterprise_core_info"
  enterprise_id = var.enterprise_id
}

module "az_copy_files" {
  count                         = var.is_upgrade ? 1 : 0
  source                        = "../../modules/az_copy_files"
  storage_account_blob_endpoint = module.enterprise_core_info.storage_account_blob_endpoint
  container_name                = "repository"
  index_file                    = local.manifest_file_path
}

# Install Chef Client and Chef Cookbooks for ArcGIS on all VMs of the deployment
module "bootstrap_deployment" {
  source        = "../../modules/bootstrap"
  enterprise_id = var.enterprise_id
  deployment_id = var.deployment_id
  machine_roles = ["primary", "standby"]
  os            = nonsensitive(data.azurerm_key_vault_secret.vm_image_os.value)
}

# Download base ArcGIS Enterprise setup archives to primary and standby VMs
module "arcgis_enterprise_files" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-files"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = templatefile(
    local.manifest_file_path,
    {
      account_name   = module.enterprise_core_info.storage_account_name
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

# Upgrade base ArcGIS Enterprise software on primary and standby VMs
module "arcgis_enterprise_upgrade" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-upgrade"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      server = {
        install_dir                 = "/opt"
        configure_autostart         = true
        install_system_requirements = true
      }
      data_store = {
        install_dir                 = "/opt"
        setup_options               = "-f Relational"
        data_dir                    = "/gisdata/arcgisdatastore"
        configure_autostart         = true
        preferredidentifier         = "ip"
        install_system_requirements = true
      }
      portal = {
        install_dir                 = "/opt"
        configure_autostart         = true
        install_system_requirements = true
        preferredidentifier         = "ip"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::stop_portal]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::start_portal]",
      "recipe[arcgis-enterprise::stop_server]",
      "recipe[arcgis-enterprise::install_server]",
      "recipe[arcgis-enterprise::start_server]",
      "recipe[arcgis-enterprise::stop_datastore]",
      "recipe[arcgis-enterprise::install_datastore]",
      "recipe[arcgis-enterprise::start_datastore]"
    ]
  })
  execution_timeout = 7200
  depends_on = [
    module.arcgis_enterprise_files
  ]
}

# Patch base ArcGIS Enterprise software on primary and standby VMs
module "arcgis_enterprise_patch" {
  count                  = var.is_upgrade ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-patch"
  enterprise_id          = var.enterprise_id
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
module "arcgis_enterprise_fileserver" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-fileserver"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      fileserver = {
        directories = [
          "${local.mount_point}/gisdata/arcgisserver",
          "${local.mount_point}/gisdata/arcgisbackup/webgisdr"
        ]
        shares = []
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
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
  storage_account_name   = module.enterprise_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.server_authorization_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.server_authorization_file_path))
}

# Upload Portal for ArcGIS authorization file to the private repository blob container
resource "azurerm_storage_blob" "portal_authorization_file" {
  name                   = "${local.authorization_files_prefix}/${basename(var.portal_authorization_file_path)}"
  storage_account_name   = module.enterprise_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.portal_authorization_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.portal_authorization_file_path))
}

# If specified, upload root certificate file to the private repository blob container
resource "azurerm_storage_blob" "root_cert_file" {
  count                  = var.root_cert_file_path != null ? 1 : 0
  name                   = "${local.certificates_prefix}/${basename(var.root_cert_file_path)}"
  storage_account_name   = module.enterprise_core_info.storage_account_name
  storage_container_name = "repository"
  source                 = pathexpand(var.root_cert_file_path)
  type                   = "Block"
  content_md5            = filemd5(pathexpand(var.root_cert_file_path))
}

# Download ArcGIS Server and Portal authorization files to primary and standby VMs
module "authorization_files" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-authorization-files"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.authorization_files_dir
        server = {
          account_name   = module.enterprise_core_info.storage_account_name
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
      azure_cli = {
        install_dir = "/usr"
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

# Download keystore files to primary and standby VMs
module "primary_keystore" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-primary-keystore-file"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.certificates_dir
        server = {
          account_name   = module.enterprise_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${local.primary_hostname}.pfx" = {
            subfolder = local.certificates_prefix
          }
        }
      }
      azure_cli = {
        install_dir = "/usr"
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

module "standby_keystore" {
  count                  = local.is_ha ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-standby-keystore-file"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.certificates_dir
        server = {
          account_name   = module.enterprise_core_info.storage_account_name
          container_name = "repository"
          auth_mode      = "login"
          client_id      = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        files = {
          "${local.standby_hostname}.pfx" = {
            subfolder = local.certificates_prefix
          }
        }
      }
      azure_cli = {
        install_dir = "/usr"
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

# Download root certificate file to primary and standby VMs
module "root_cert" {
  count                  = var.root_cert_file_path != null ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-root-cert"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary", "standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      configure_cloud_settings = false
      repository = {
        local_archives = local.certificates_dir
        server = {
          account_name   = module.enterprise_core_info.storage_account_name
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
      azure_cli = {
        install_dir = "/usr"
      }
    }
    run_list = [
      "recipe[arcgis-repository::azure_files]"
    ]
  })
  depends_on = [
    module.authorization_files,
    azurerm_storage_blob.root_cert_file
  ]
}

# Configure base ArcGIS Enterprise on primary VM
module "arcgis_enterprise_primary" {
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-primary"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["primary"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      server = {
        url                            = "https://${local.primary_hostname}:6443/arcgis"
        install_dir                    = "/opt"
        private_url                    = "https://${local.ingress_fqdn}/${local.server_web_context}"
        web_context_url                = "https://${local.ingress_fqdn}/${local.server_web_context}"
        hostname                       = local.primary_hostname
        admin_username                 = var.admin_username
        admin_password                 = var.admin_password
        authorization_file             = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
        authorization_options          = var.server_authorization_options
        keystore_file                  = local.primary_keystore_file
        keystore_password              = data.azurerm_key_vault_secret.backend_pfx_password.value
        cert_alias                     = "servercert"
        root_cert                      = local.root_cert
        root_cert_alias                = "rootcert"
        directories_root               = "${local.mount_point}/gisdata/arcgisserver"
        log_dir                        = "/opt/arcgis/server/usr/logs"
        log_level                      = var.log_level
        config_store_type              = var.config_store_type
        config_store_connection_string = "${local.mount_point}/gisdata/arcgisserver/config-store"
        cloud_config                   = local.cloud_config
        install_system_requirements    = true
        services_dir_enabled           = true
        callback_functions_enabled     = true
        system_properties = {
          WebContextURL = "https://${local.ingress_fqdn}/${local.server_web_context}"
        }
        data_items = local.data_items
      }
      data_store = {
        install_dir                 = "/opt"
        setup_options               = "-f Relational"
        data_dir                    = "/gisdata/arcgisdatastore"
        preferredidentifier         = "ip"
        hostidentifier              = local.primary_hostname
        install_system_requirements = true
        types                       = "relational"
        relational = {
          enablessl               = true
          disk_threshold_readonly = 5120
          max_connections         = 150
          pitr                    = "enable"
          backup_type             = "s3"
          backup_location         = "type=azure;location=datastore-backups/${var.deployment_id}/relational;name=re_default;username=${module.enterprise_core_info.storage_account_name};password=${module.enterprise_core_info.storage_account_key}"
        }
      }
      portal = {
        url                         = "https://${local.primary_hostname}:7443/arcgis"
        preferredidentifier         = "ip"
        hostname                    = local.primary_hostname
        hostidentifier              = local.primary_hostname
        install_dir                 = "/opt"
        install_system_requirements = true
        private_url                 = "https://${local.ingress_fqdn}/${local.portal_web_context}"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        admin_email                 = var.admin_email
        admin_full_name             = var.admin_full_name
        admin_description           = var.admin_description
        security_question_index     = var.security_question_index
        security_question_answer    = var.security_question_answer
        log_dir                     = "/opt/arcgis/portal/usr/arcgisportal/logs"
        log_level                   = var.log_level
        content_store_type          = "cloudStore"
        content_store_provider      = "Azure"
        content_store_connection_string = {
          accountName             = local.storage_account_name
          accountEndpoint         = "blob.core.windows.net"
          credentialType          = "userAssignedIdentity"
          managedIdentityClientId = data.azurerm_key_vault_secret.vm_identity_client_id.value
        }
        object_store         = "${local.storage_account_blob_endpoint}/portal-content"
        authorization_file   = "${local.authorization_files_dir}/${basename(var.portal_authorization_file_path)}"
        user_license_type_id = var.portal_user_license_type_id
        keystore_file        = local.primary_keystore_file
        keystore_password    = data.azurerm_key_vault_secret.backend_pfx_password.value
        cert_alias           = "portalcert"
        root_cert            = local.root_cert
        root_cert_alias      = "rootcert"
        system_properties = {
          privatePortalURL = "https://${local.ingress_fqdn}/${local.portal_web_context}"
          WebContextURL    = "https://${local.ingress_fqdn}/${local.portal_web_context}"
        }
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal]",
      "recipe[arcgis-enterprise::server]",
      "recipe[arcgis-enterprise::datastore]",
      "recipe[arcgis-enterprise::server_data_items]",
      "recipe[arcgis-enterprise::federation]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.authorization_files,
    module.primary_keystore,
    module.root_cert
  ]
}

# Configure base ArcGIS Enterprise on standby VM
module "arcgis_enterprise_standby" {
  count                  = local.is_ha ? 1 : 0
  source                 = "../../modules/run_chef"
  json_attributes_secret = "${var.deployment_id}-standby"
  enterprise_id          = var.enterprise_id
  deployment_id          = var.deployment_id
  machine_roles          = ["standby"]
  json_attributes = jsonencode({
    arcgis = {
      version                  = var.arcgis_version
      run_as_user              = var.run_as_user
      configure_cloud_settings = false
      repository = {
        archives = local.archives_dir
        setups   = "/opt/software/setups"
      }
      server = {
        url                         = "https://${local.standby_hostname}:6443/arcgis"
        hostname                    = local.standby_hostname
        install_dir                 = "/opt"
        primary_server_url          = "https://${local.primary_hostname}:6443/arcgis"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        log_dir                     = "/opt/arcgis/server/usr/logs"
        authorization_file          = "${local.authorization_files_dir}/${basename(var.server_authorization_file_path)}"
        authorization_options       = var.server_authorization_options
        keystore_file               = local.standby_keystore_file
        keystore_password           = data.azurerm_key_vault_secret.backend_pfx_password.value
        cert_alias                  = "servercert"
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
        install_system_requirements = true
      }
      data_store = {
        install_dir                 = "/opt"
        setup_options               = "-f Relational"
        data_dir                    = "/gisdata/arcgisdatastore"
        preferredidentifier         = "ip"
        hostidentifier              = local.standby_hostname
        install_system_requirements = true
        types                       = "relational"
      }
      portal = {
        url                         = "https://${local.standby_hostname}:7443/arcgis"
        preferredidentifier         = "ip"
        hostname                    = local.standby_hostname
        hostidentifier              = local.standby_hostname
        install_dir                 = "/opt"
        install_system_requirements = true
        primary_machine_url         = "https://${local.primary_hostname}:7443"
        admin_username              = var.admin_username
        admin_password              = var.admin_password
        log_dir                     = "/opt/arcgis/portal/usr/arcgisportal/logs"
        keystore_file               = local.standby_keystore_file
        keystore_password           = data.azurerm_key_vault_secret.backend_pfx_password.value
        cert_alias                  = "portalcert"
        root_cert                   = local.root_cert
        root_cert_alias             = "rootcert"
      }
    }
    run_list = [
      "recipe[arcgis-enterprise::system]",
      "recipe[arcgis-enterprise::install_portal]",
      "recipe[arcgis-enterprise::webstyles]",
      "recipe[arcgis-enterprise::portal_standby]",
      "recipe[arcgis-enterprise::server_node]",
      "recipe[arcgis-enterprise::datastore_standby]"
    ]
  })
  execution_timeout = 14400
  depends_on = [
    module.arcgis_enterprise_primary,
    module.standby_keystore,
    module.root_cert
  ]
}

# Delete the downloaded setup archives, the extracted setups, and other 
# temporary files from primary and standby VMs.
module "clean_up" {
  source                = "../../modules/clean_up"
  enterprise_id         = var.enterprise_id
  deployment_id         = var.deployment_id
  machine_roles         = ["primary", "standby"]
  directories           = [local.software_dir]
  uninstall_chef_client = false
  depends_on = [
    module.arcgis_enterprise_primary,
    module.arcgis_enterprise_standby
  ]
}
