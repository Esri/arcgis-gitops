# Packer Template for Base ArcGIS Enterprise on Windows Images

The Packer templates builds VM images for a specific base ArcGIS Enterprise deployment.

The images are built from a Windows OS base image specified by Key Vault secret "vm-image-${var.os}".

The template first copies installation media for the ArcGIS Enterprise version and required third party dependencies from My Esri and public repositories to the private "repository" blob container in Azure storage account specified by "storage-account-name" Key Vault Secret. The files to copy are specified in ../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json index file.

Then the template uses python scripts to run Azure Managed Run Command on the source VM instances.

1. Install Azure CLI
2. Install Cinc Client and Chef Cookbooks for ArcGIS
3. Download setups from the private "repository" blob container in Azure storage account.
4. Install base ArcGIS Enterprise applications
5. Install patches for the base ArcGIS Enterprise applications
6. Delete unused files, uninstall Cinc Client, run sysprep

IDs of the images are saved in "vm-image-${var.site_id}-${var.deployment_id}-primary" and "vm-image-${var.site_id}-${var.deployment_id}-standby" Key Vault secrets.

## Requirements

On the machine where Packer is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, and azure-mgmt-compute azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured.
* My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD or the input variables.

## Key Vault Secrets

The template reads the following Key Vault secrets:

| Key Vault secret name | Description |
|-----------------------|-------------|
| chef-client-url-${var.os} | Chef Client URL |
| cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
| vm-identity-id | Managed identity resource Id |
| vm-identity-client-id | Managed identity client Id |
| vm-image-${var.os} | Source VM Image Id |
| storage-account-name | Private repository storage account name |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| azure_region | Azure region display name | `string` | `env("AZURE_DEFAULT_REGION")` | no |
| arcgis_data_store_patches | File names of ArcGIS Data Store patches to install | `string` | `[]` | no |
| arcgis_portal_patches | File names of Portal for ArcGIS patches to install | `string` | `[]` | no |
| arcgis_server_patches | File names of ArcGIS Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Enterprise version | `string` | `"11.5"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `string` | `[]` | no |
| deployment_id | Deployment Id | `string` | `"enterprise-base-windows"` | no |
| vm_size | Azure VM size | `string` | `"Standard_D8s_v5"` | no |
| os | Operating system Id | `string` | `"windows2025"` | no |
| portal_web_context | Portal for ArcGIS web context | `string` | `"portal"` | no |
| os_disk_size | OS disk size in GB | `number` | `256` | no |
| run_as_password | Password for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `env("RUN_AS_PASSWORD")` | yes |
| run_as_user | User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Server web context | `string` | `"server"` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |
| skip_create_image | If true, Packer will not create the image | `bool` | `false` | no |
