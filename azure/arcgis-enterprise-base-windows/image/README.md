# Packer Template for Base ArcGIS Enterprise on Windows Images

The Packer template builds application and file-server VM images for a base ArcGIS Enterprise deployment on Windows and publishes them to the enterprise Image Gallery.

The images are built from a Windows OS base image specified by Key Vault secret "vm-image-${var.os}".

The application build runs these steps:

1. Install Azure CLI on the build VM through the builder's user-data script.
2. Use Packer's PowerShell provisioner to initialize and verify the persistent LUN 0 data disk as NTFS at `D:`.
3. Bootstrap the VM with Cinc Client and Chef Cookbooks for ArcGIS through Azure Managed Run Command.
4. Copy installation media and third-party dependencies from My Esri and public repositories to the private `repository` blob container in the account named by the `storage-account-name` Key Vault secret. The files are listed in `../manifests/arcgis-enterprise-azure-files-${var.arcgis_version}.json`.
5. Use Azure Managed Run Command to download the setups to the VM, install the ArcGIS Enterprise applications, and apply the configured patches.
6. Use Packer's PowerShell provisioner to prepare `D:\data`, grant built-in Users inheritable Full Control there, and record the exact service-account SID and matching data disk lineage.
7. Remove unused files through Azure Managed Run Command, leaving Cinc Client installed. Run Sysprep through Packer's PowerShell provisioner before image capture.

Before recording the application image identity, the build changes the verified
`D:\` root owner from Network Service (`S-1-5-20`) to built-in Administrators
if needed. It does not change the root access rules or relax the identity
parent checks.

The same application gallery image version ID is saved in the `${var.deployment_id}-vm-image-primary` and `${var.deployment_id}-vm-image-standby` Key Vault secrets. A separate Packer build creates a generalized file-server gallery image version from the same base Windows OS image without installing the ArcGIS application stack. Its version ID is saved in `${var.deployment_id}-vm-image-fileserver`.

## Requirements

On the machine where Packer is executed:

* Packer and Azure CLI must be installed
* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured using `az login`, with the target subscription selected using `az account set --subscription <subscription-id>`
* My Esri user name and password must be supplied through the environment variables `ARCGIS_ONLINE_USERNAME` and `ARCGIS_ONLINE_PASSWORD`; the template does not define credential input variables

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

The template writes the following image version IDs and deployment metadata to Key Vault:

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
| azure_cli_url | URL for the Azure CLI installer | `string` | `"https://azcliprod.blob.core.windows.net/msi/azure-cli-2.76.0-x64.msi"` | no |
| azure_region | Azure region display name | `string` | `env("AZURE_DEFAULT_REGION")` | no |
| deployment_id | Deployment ID | `string` | `"enterprise-base-windows"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| os | Operating system ID | `string` | `"windows2025"` | no |
| os_disk_size | OS disk size in GB | `number` | `256` | no |
| data_disk_size | Persistent application data disk capacity baked into the gallery image, in whole GiB (128 to 32,767) | `number` | `256` | no |
| portal_web_context | Portal for ArcGIS web context | `string` | `"portal"` | no |
| run_as_password | Password for the account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. Supply a value for the application build through this input or `RUN_AS_PASSWORD`. | `string` | `env("RUN_AS_PASSWORD")` | no (defaults to the environment variable) |
| run_as_user | User account used to run ArcGIS Server, Portal for ArcGIS, and ArcGIS Data Store. | `string` | `"arcgis"` | no |
| server_web_context | ArcGIS Server web context | `string` | `"server"` | no |
| skip_create_image | If true, Packer will not create the image | `bool` | `false` | no |
| vault_name | Name of the Azure Key Vault | `string` | None | yes |
| vm_size | Azure VM size | `string` | `"Standard_D8s_v5"` | no |
