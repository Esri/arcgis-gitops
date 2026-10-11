# Packer Template for Base ArcGIS Enterprise on Windows Images

The Packer template builds VM images for a specific base ArcGIS Enterprise deployment on Windows and publishes it to the enterprise Image Gallery.

The images are built from a Windows OS base image specified by Key Vault secret "vm-image-${var.os}".

The template first copies installation media for the ArcGIS Enterprise version and required third party dependencies from My Esri and public repositories to the private "repository" blob container in Azure storage account specified by "storage-account-name" Key Vault Secret. The files to copy are specified in ../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json index file.

Then the template uses python scripts to run Azure Managed Run Command on the source VM instances.

1. Install Azure CLI
2. Install Cinc Client and Chef Cookbooks for ArcGIS
3. Download setups from the private "repository" blob container in Azure storage account.
4. Install base ArcGIS Enterprise applications
5. Install patches for the base ArcGIS Enterprise applications
6. Delete unused files, uninstall Cinc Client, run sysprep

IDs of the ArcGIS images are saved in "${var.deployment_id}-vm-image-primary" and "${var.deployment_id}-vm-image-standby" Key Vault secrets. A separate Packer build creates a generalized file-server gallery image version from the same base Windows OS image without installing the ArcGIS application stack. Its built image version ID is saved in "${var.deployment_id}-vm-image-fileserver" after the build succeeds.

The file-server image installs Azure CLI using the same user-data script and `azure_cli_url` as the ArcGIS image. Before Sysprep, the build refreshes PATH, verifies that `az` resolves, and runs `az version`; a missing or nonfunctional CLI fails the build before image publication. Azure CLI is required for application bootstrap to authenticate using the VM's managed identity.

For deployments using a file-server image built without Azure CLI, rerun the image workflow and recreate the failed file-server VM through the approved deployment workflow using the new image version. Existing images and VMs are not updated by this template change. For rollback, use a previously verified file-server gallery image version.

## Requirements

VM image definitions "${var.deployment_id}-${var.arcgis_version}-${var.os}" and "${var.deployment_id}-fileserver-${var.os}" must exist in the enterprise Image Gallery before running the template. The image workflow creates both definitions; create both before running Packer directly. The destroy workflow removes both definitions and their versions.

On the machine where Packer is executed:

 * Python 3.9 or later must be installed
 * azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
 * Path to azure/scripts directory must be added to PYTHONPATH
 * Azure credentials must be configured using "az login" command
 * My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables

## Key Vault Secrets

The template reads the following Key Vault secrets:

| Key Vault secret name     | Description |
|---------------------------|-------------|
| chef-client-url-${var.os} | Chef Client URL |
| cookbooks-url             | Chef Cookbooks for ArcGIS archive URL |
| image-gallery-name        | Enterprise Image Gallery name |
| storage-account-name      | Private repository storage account name |
| vm-identity-client-id     | Managed identity client ID |
| vm-identity-id            | Managed identity resource ID |
| vm-image-${var.os}        | Source VM Image ID |

The template saves the built image ID in the following Key Vault secrets:

| Key Vault secret name                   | Description |
|-----------------------------------------|-------------|
| ${var.deployment_id}-os                 | Operating system ID |
| ${var.deployment_id}-portal-web-context | Portal for ArcGIS web context |
| ${var.deployment_id}-server-web-context | ArcGIS Server web context |
| ${var.deployment_id}-vm-image-primary   | Built image ID for primary node |
| ${var.deployment_id}-vm-image-standby   | Built image ID for standby node |
| ${var.deployment_id}-vm-image-fileserver | Built file-server gallery image version ID |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_data_store_patches | File names of ArcGIS Data Store patches to install | `list(string)` | `[]` | no |
| arcgis_portal_patches | File names of Portal for ArcGIS patches to install | `list(string)` | `[]` | no |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Enterprise version | `string` | `"12.1"` | no |
| azure_region | Azure region display name | `string` | `env("AZURE_DEFAULT_REGION")` | no |
| deployment_id | Deployment ID | `string` | `"enterprise-base-windows"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| os | Operating system ID | `string` | `"windows2025"` | no |
| os_disk_size | OS disk size in GB | `number` | `256` | no |
| portal_web_context | Portal for ArcGIS web context | `string` | `"portal"` | no |
| run_as_password | Password for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `env("RUN_AS_PASSWORD")` | yes |
| run_as_user | User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Server web context | `string` | `"server"` | no |
| skip_create_image | If true, Packer will not create the image | `bool` | `false` | no |
| vm_size | Azure VM size | `string` | `"Standard_D8s_v5"` | no |
