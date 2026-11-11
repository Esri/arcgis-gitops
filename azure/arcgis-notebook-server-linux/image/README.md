# Packer Template for ArcGIS Notebook Server on Linux

The Packer template builds a VM image for a specific ArcGIS Notebook Server deployment and
publishes it to the enterprise Image Gallery.

The VM image is built from the operating system's base image specified by Key Vault secret "vm-image-${var.os}".

The template uses shell provisioners over SSH and Python scripts that invoke
Azure Managed Run Command to prepare the source VM:

1. Initialize the persistent data disk at LUN 0 and mount it at `/opt`
2. Install Azure CLI and Docker CE; if gpu_ready is true, install NVIDIA drivers and CUDA toolkit
3. Install Cinc Client and Chef Cookbooks for ArcGIS
4. Copy setup and patch files specified by the version-specific manifest to the private repository Azure Storage blob container
5. Download setups from the private repository Azure Storage blob container to the source VM
6. Install OpenJDK, Apache Tomcat, ArcGIS Notebook Server, and ArcGIS Web Adaptor for Java
7. Install patches for the ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
8. Verify that `/opt` and Docker storage at `/opt/docker` use the data disk
9. Delete temporary files and uninstall Cinc Client

The image ID is saved in "${var.deployment_id}-vm-image-primary" 
and "${var.deployment_id}-vm-image-node" Key Vault secrets.

## Requirements

VM image definition "${var.deployment_id}-${var.arcgis_version}-${var.os}" 
must be created in the enterprise Image Gallery before running the template.

On the machine where Packer is executed:

* Packer must be installed, and the Azure plugin must be initialized by running `packer init .` from this image directory
* SSH connectivity to the temporary build VM must be available for Packer's SSH communicator and shell provisioners
* Python 3.9 or later must be installed
* Azure Python SDK packages azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure CLI must be installed and configured
* Azure credentials must be configured using "az login" CLI command
* My Esri user name and password must be specified using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD

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

The template writes the following Key Vault secrets:

| Key Vault secret name                            | Description |
|--------------------------------------------------|-------------|
| ${var.deployment_id}-notebook-server-web-context | ArcGIS Notebook Server web context |
| ${var.deployment_id}-os                          | Operating system ID |
| ${var.deployment_id}-vm-image-node               | Built image ID for additional nodes |
| ${var.deployment_id}-vm-image-primary            | Built image ID for primary node |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_notebook_server_patches | File names of ArcGIS Notebook Server patches to install | `list(string)` | `[]` | no |
| arcgis_version | ArcGIS Notebook Server version | `string` | `"12.1"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `list(string)` | `[]` | no |
| azure_cli_version | Version of Azure CLI to install on the image | `string` | `"2.76.0"` | no |
| azure_region | Azure region display name | `string` | `env("AZURE_DEFAULT_REGION")` | no |
| data_disk_size | Persistent /opt data disk capacity baked into the image in GiB | `number` | `256` | no |
| deployment_id | Deployment ID | `string` | `"notebook-server-linux"` | no |
| docker_version | Version of Docker CE to install on the image | `string` | `"29.3.1"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| gpu_ready | If true, the image is built with GPU support | `bool` | `false` | no |
| license_level | ArcGIS Notebook Server license level | `string` | `"standard"` | no |
| notebook_server_web_context | ArcGIS Notebook Server web context | `string` | `"notebooks"` | no |
| os | Operating system ID (rhel9\|ubuntu24) | `string` | `"rhel9"` | no |
| os_disk_size | OS disk size in GB | `number` | `256` | no |
| run_as_user | User account used to run ArcGIS Notebook Server | `string` | `"arcgis"` | no |
| skip_create_image | If true, Packer will not create the image | `bool` | `false` | no |
| vault_name | Name of the Azure Key Vault | `string` | n/a | yes |
| vm_size | Size of the source VM used to build the image | `string` | `"Standard_D8s_v5"` | no |
