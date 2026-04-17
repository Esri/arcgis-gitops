/**
 * # Infrastructure Terraform Module for ArcGIS Notebook Server on Linux
 *
 * The Terraform module provisions Azure resources for ArcGIS Notebook Server deployment on Linux platform.
 *
 * ![Infrastructure for ArcGIS Notebook Server on Linux](arcgis-notebook-server-linux-infrastructure.png "Infrastructure for ArcGIS Notebook Server on Linux")  
 *
 * The module creates network interfaces in the first private subnet or the subnet specified by subnet_id input variable and
 * launches one primary and N node VMs (configurable via node_count) in different zones of the specified Azure region.
 * The VMs are launched from images retrieved from "${var.deployment_id}-vm-image-primary" and "${var.deployment_id}-vm-image-node" secrets of the site's Key Vault. 
 * The images must be created by the Packer Template for ArcGIS Notebook Server on Linux. 
 *  
 * The network interfaces are associated with the backend address pool "notebook-server" of the Application Gateway created by the ingress 
 * Terraform module to make the VMs accessible from the Application Gateway.
 *
 * For the VMs the module creates "A" records in the internal private DNS zone to make them addressable using the permanent DNS names.
 *
 * > Note that the VMs will be terminated and recreated if the infrastructure Terraform module
 *   is applied again after the image IDs in the Key Vault secrets were modified by a new image build.
 *
 * The module creates two storage accounts: one for ArcGIS Notebook Server config store and another for file store with "fileserver" NFS file share.
 * The config store storage account is secured with private endpoints and only accessible from the VMs.
 * The VM identity is granted access to the config store storage account.
 * The file share is mounted to all the VMs. 
 *
 * The module also extends the root volume on the VMs and mounts the file share to the VMs. 
 *
 * The module creates a certificate for backend services/endpoints signed by the ingress CA and 
 * uploads the certificate to the repository storage container.
 *  
 * The deployment's Monitoring Subsystem consists of a shared dashboard in Azure Monitor that displays 
 * the key metrics of the deployment's VMs and storage infrastructure.
 *
 * All the created Azure resources are tagged with ArcGISSiteId and ArcGISDeploymentId tags.
 *
 * ## Requirements
 *
 * On the machine where Terraform is executed:
 * 
 * * Python 3.9 or later must be installed
 * * azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
 * * Path to azure/scripts directory must be added to PYTHONPATH
 * * Azure credentials must be configured using "az login" command
 *
 * ## Key Vault Secrets
 *
 * ### Secrets Read by the Module
 *
 * | Secret Name                                        | Description |
 * |----------------------------------------------------|-------------|
 * | ${var.deployment_id}-notebook-server-web-context   | Notebook Server web context |
 * | ${var.deployment_id}-os                            | Operating system ID |
 * | ${var.deployment_id}-vm-image-node                 | Node VM image ID |
 * | ${var.deployment_id}-vm-image-primary              | Primary VM image ID |
 * | ${var.ingress_deployment_id}-backend-address-pools | Application Gateway backend address pools |
 * | ${var.ingress_deployment_id}-ca-private-key        | Private key of the ingress CA root certificate |
 * | ${var.ingress_deployment_id}-ca-root-cert          | Root certificate used by Application Gateway to validate the backend's identity |  
 * | ${var.ingress_deployment_id}-deployment-fqdn       | Ingress deployment FQDN |
 * | ${var.portal_deployment_id}-deployment-url         | Portal deployment URL |
 * | storage-account-key                                | Site storage account key |
 * | storage-account-name                               | Site storage account name |
 * | subnets                                            | VNet subnet IDs |
 * | vm-identity-id                                     | User-assigned VM identity resource ID |
 * | vm-identity-principal-id                           | User-assigned VM identity principal ID |
 * | vnet-id                                            | VNet ID |
 *
 * ### Secrets Written by the Module
 *
 * | Secret Name                               | Description |
 * |-------------------------------------------|-------------|
 * | ${var.deployment_id}-backend-pfx-password | Password for the PFX certificate |
 * | ${var.deployment_id}-deployment-fqdn      | Deployment's FQDN |
 * | ${var.deployment_id}-deployment-url       | Deployment URL |
 * | ${var.deployment_id}-portal-url           | Portal URL |
 * | ${var.deployment_id}-storage-account-name | Config Store's storage account name |
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
    key = "terraform/arcgis/notebook-server-linux/infrastructure.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.46"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.2"
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

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_secret" "vm_identity_id" {
  name         = "vm-identity-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_identity_principal_id" {
  name         = "vm-identity-principal-id"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "primary_vm_image_id" {
  name         = "${var.deployment_id}-vm-image-primary"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "node_vm_image_id" {
  name         = "${var.deployment_id}-vm-image-node"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "backend_address_pools" {
  name         = "${var.ingress_deployment_id}-backend-address-pools"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.ingress_deployment_id}-deployment-fqdn"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "portal_deployment_url" {
  name         = "${var.portal_deployment_id}-deployment-url"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "vm_image_os" {
  name         = "${var.deployment_id}-os"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_key_vault_secret" "notebook_server_web_context" {
  name         = "${var.deployment_id}-notebook-server-web-context"
  key_vault_id = module.site_core_info.vault_id
}

data "azurerm_private_dns_zone" "privatelink_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

data "azurerm_private_dns_zone" "privatelink_table" {
  name                = "privatelink.table.core.windows.net"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

data "azurerm_private_dns_zone" "privatelink_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = "${var.site_id}-infrastructure-core"
}

locals {
  deployment_fqdn             = nonsensitive(data.azurerm_key_vault_secret.deployment_fqdn.value)
  notebook_server_web_context = nonsensitive(data.azurerm_key_vault_secret.notebook_server_web_context.value)

  vm_roles                = ["primary", "node"]
  zones                   = ["1", "2"]
  subnet_id               = var.subnet_id != null ? var.subnet_id : element(module.site_core_info.private_subnets, 0)
  backend_address_pool_id = jsondecode(data.azurerm_key_vault_secret.backend_address_pools.value)["notebook-server"]
}

module "site_core_info" {
  source  = "../../modules/site_core_info"
  site_id = var.site_id
}

resource "azurerm_resource_group" "deployment_rg" {
  name     = "${var.site_id}-${var.deployment_id}-rg"
  location = var.azure_region
}

resource "azurerm_network_interface" "primary" {
  name                = "primary-nic"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.deployment_rg.name

  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "primary"
  }
}

resource "azurerm_network_interface" "nodes" {
  count               = var.node_count
  name                = "node-nic-${count.index}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.deployment_rg.name

  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    primary                       = true
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "node"
  }
}

resource "azurerm_orchestrated_virtual_machine_scale_set" "vmss" {
  name                = var.deployment_id
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name

  platform_fault_domain_count = 1
  zones                       = local.zones
}

# Create the primary VM as part of the scale set to ensure it is distributed in a different zone than the node VMs.
resource "azurerm_linux_virtual_machine" "primary" {
  name                         = "primary"
  resource_group_name          = azurerm_resource_group.deployment_rg.name
  location                     = azurerm_resource_group.deployment_rg.location
  virtual_machine_scale_set_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  size = var.vm_size

  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = var.vm_admin_public_ssh_key_path != null

  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true

  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "ImageDefault"

  source_image_id = data.azurerm_key_vault_secret.primary_vm_image_id.value

  network_interface_ids = [
    azurerm_network_interface.primary.id
  ]

  # Make admin_ssh_key optional by checking if the vm_admin_public_ssh_key_path variable is set. 
  # If it is not set, the VMs will be created without SSH key authentication.
  dynamic "admin_ssh_key" {
    for_each = var.vm_admin_public_ssh_key_path != null ? [1] : []
    content {
      username   = var.vm_admin_username
      public_key = file(var.vm_admin_public_ssh_key_path)
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_key_vault_secret.vm_identity_id.value
    ]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "primary"
  }

  # Ignore changes to admin username and password to prevent VM replacement when these values are updated
  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password,
      zone
    ]
  }
}

# Create node VMs in a scale set to ensure they are automatically distributed across availability zones.
resource "azurerm_linux_virtual_machine" "nodes" {
  count                        = var.node_count
  name                         = "node-${count.index + 1}"
  resource_group_name          = azurerm_resource_group.deployment_rg.name
  location                     = azurerm_resource_group.deployment_rg.location
  virtual_machine_scale_set_id = azurerm_orchestrated_virtual_machine_scale_set.vmss.id

  size = var.vm_size

  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = var.vm_admin_public_ssh_key_path != null

  encryption_at_host_enabled = true
  secure_boot_enabled        = true
  vtpm_enabled               = true

  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "ImageDefault"

  source_image_id = data.azurerm_key_vault_secret.node_vm_image_id.value

  network_interface_ids = [
    azurerm_network_interface.nodes[count.index].id
  ]

  # Make admin_ssh_key optional by checking if the vm_admin_public_ssh_key_path variable is set. If it is not set, the VMs will be created without SSH key authentication.
  dynamic "admin_ssh_key" {
    for_each = var.vm_admin_public_ssh_key_path != null ? [1] : []
    content {
      username   = var.vm_admin_username
      public_key = file(var.vm_admin_public_ssh_key_path)
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.os_disk_size
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      data.azurerm_key_vault_secret.vm_identity_id.value
    ]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "node"
  }

  # Ignore changes to admin username and password to prevent VM replacement when these values are updated
  lifecycle {
    ignore_changes = [
      admin_username,
      admin_password,
      zone
    ]
  }
}

resource "random_id" "unique_name_suffix" {
  keepers = {
    # Generate a new id each time we switch to a new site id
    site_id = var.site_id
  }

  byte_length = 8
}

resource "azurerm_storage_account" "config_store" {
  name                = "gis${random_id.unique_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location

  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = var.storage_replication_type

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [local.subnet_id]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "config-store"
  }
}

resource "azurerm_private_endpoint" "config_store_blob_pe" {
  name                = "${azurerm_storage_account.config_store.name}-blob--pe"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.config_store.id
    subresource_names              = ["blob"] # Target the Blob service
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.privatelink_blob.id]
  }
}

resource "azurerm_private_endpoint" "config_store_table_pe" {
  name                = "${azurerm_storage_account.config_store.name}-table--pe"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.config_store.id
    subresource_names              = ["table"] # Target the Table service
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.privatelink_table.id]
  }
}

# Assign permissions to the VM user assigned identity to allow it to access the storage account 
# via Blob and Table services through the private endpoints.
resource "azurerm_role_assignment" "blob_store" {
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Storage Blob Data Contributor"
  scope                            = azurerm_storage_account.config_store.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "table_store" {
  principal_id                     = data.azurerm_key_vault_secret.vm_identity_principal_id.value
  role_definition_name             = "Storage Table Data Contributor"
  scope                            = azurerm_storage_account.config_store.id
  skip_service_principal_aad_check = true
}

# Storage Account with NFS File Share
resource "azurerm_storage_account" "file_store" {
  name                = "nfs${random_id.unique_name_suffix.hex}"
  resource_group_name = azurerm_resource_group.deployment_rg.name
  location            = azurerm_resource_group.deployment_rg.location

  account_tier             = "Premium"
  account_kind             = "FileStorage" # Required for NFS
  account_replication_type = var.storage_replication_type

  # NFS also requires this:
  https_traffic_only_enabled = false

  # Ensure HNS is disabled 
  is_hns_enabled = false

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [local.subnet_id]
  }

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
    ArcGISRole         = "file-store"
  }
}

# Create a private endpoint for the storage account to enable secure, private connectivity from the VMs to the storage account.
resource "azurerm_private_endpoint" "file_store_pe" {
  name                = "${azurerm_storage_account.file_store.name}-pe"
  location            = azurerm_resource_group.deployment_rg.location
  resource_group_name = azurerm_resource_group.deployment_rg.name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.file_store.id
    subresource_names              = ["file"] # Target the File service
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.privatelink_file.id]
  }
}

resource "azurerm_storage_share" "fileserver" {
  name               = "fileserver"
  storage_account_id = azurerm_storage_account.file_store.id
  enabled_protocol   = "NFS"
  quota              = var.fileserver_size
}

# Extend the root volume on the VMs.
module "lv_extend" {
  source        = "../../modules/lv_extend"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = [
    "primary",
    "node"
  ]
  os = nonsensitive(data.azurerm_key_vault_secret.vm_image_os.value)

  depends_on = [
    azurerm_linux_virtual_machine.primary,
    azurerm_linux_virtual_machine.nodes,
    azurerm_storage_share.fileserver,
    azurerm_private_endpoint.file_store_pe
  ]
}

# Mount the file share to the VMs.
module "aznfs_mount" {
  source        = "../../modules/aznfs_mount"
  site_id       = var.site_id
  deployment_id = var.deployment_id
  machine_roles = [
    "primary",
    "node"
  ]
  storage_account_name = azurerm_storage_account.file_store.name
  file_share_name      = azurerm_storage_share.fileserver.name
  mount_point          = "/mnt/fileserver"

  depends_on = [
    module.lv_extend
  ]
}

# Create a record in the internal hosted zone for each VM.
# So the VMS can be addressed by their permanent DNS names like  
# primary.<deployment_id>.<site_id>.internal and
# node-1.<deployment_id>.<site_id>.internal
resource "azurerm_private_dns_a_record" "primary" {
  name                = "primary.${var.deployment_id}"
  zone_name           = "${var.site_id}.internal"
  resource_group_name = "${var.site_id}-infrastructure-core"
  ttl                 = 300
  records = [
    azurerm_linux_virtual_machine.primary.private_ip_address
  ]
}

resource "azurerm_private_dns_a_record" "nodes" {
  count               = var.node_count
  name                = "node-${count.index + 1}.${var.deployment_id}"
  zone_name           = "${var.site_id}.internal"
  resource_group_name = "${var.site_id}-infrastructure-core"
  ttl                 = 300
  records = [
    azurerm_linux_virtual_machine.nodes[count.index].private_ip_address
  ]
}

# Associate the NICs of the VMs with the backend address pool of the Application Gateway

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "primary" {
  network_interface_id    = azurerm_network_interface.primary.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = local.backend_address_pool_id
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "nodes" {
  count                   = var.node_count
  network_interface_id    = azurerm_network_interface.nodes[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = local.backend_address_pool_id
}

# Copy the ingress deployment FQDN from the ingress deployment Key Vault secret
resource "azurerm_key_vault_secret" "deployment_fqdn" {
  name         = "${var.deployment_id}-deployment-fqdn"
  value        = data.azurerm_key_vault_secret.deployment_fqdn.value
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_key_vault_secret" "deployment_url" {
  name         = "${var.deployment_id}-deployment-url"
  value        = "https://${local.deployment_fqdn}/${local.notebook_server_web_context}"
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_key_vault_secret" "portal_url" {
  name         = "${var.deployment_id}-portal-url"
  value        = nonsensitive(data.azurerm_key_vault_secret.portal_deployment_url.value)
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "${var.deployment_id}-storage-account-name"
  value        = azurerm_storage_account.config_store.name
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }
}

# Create a self-signed certificates trusted by the Application Gateway 
# and store them in the repository storage container.
resource "random_password" "pfx_password" {
  length           = 16
  special          = true
  override_special = "!#$%*()-_=+[]{}:?"
}

module "backend_cert" {
  source                 = "../../modules/backend_cert"
  deployment_id          = var.deployment_id
  ingress_id             = var.ingress_deployment_id
  common_name            = local.deployment_fqdn
  pfx_password           = random_password.pfx_password.result
  storage_account_name   = module.site_core_info.storage_account_name
  storage_container_name = "repository"
  key_vault_id           = module.site_core_info.vault_id
}

# Store the PFX password in Azure Key Vault
resource "azurerm_key_vault_secret" "pfx_password" {
  name         = "${var.deployment_id}-backend-pfx-password"
  value        = random_password.pfx_password.result
  key_vault_id = module.site_core_info.vault_id

  tags = {
    ArcGISSiteId       = var.site_id
    ArcGISDeploymentId = var.deployment_id
  }

  depends_on = [
    module.backend_cert
  ]
}
