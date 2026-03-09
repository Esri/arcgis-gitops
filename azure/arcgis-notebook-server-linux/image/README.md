# Packer Template for ArcGIS Notebook Server on Linux

The Packer templates builds VM images for a specific ArcGIS Notebook Server deployment.

The VM image is built from the operating system's base image specified by Key Vault secret "vm-image-${var.os}".

The template copies installation media for the ArcGIS Notebook Server version
and required third party dependencies from My Esri and public repositories 
to the private repository blob container. The files to be copied are specified in 
../manifests/arcgis-notebook-server-azure-files-${var.arcgis_version}.json index file.

The template uses python scripts to run Azure Managed Run Command on the source VM instances:

1. Install Azure CLI and Docker CE; if gpu_ready is true, install NVIDIA drivers and CUDA toolkit
2. Install Cinc Client and Chef Cookbooks for ArcGIS
3. Download setups from the private repository Azure Storage blob container
4. Install OpenJDK, Apache Tomcat, ArcGIS Notebook Server, and ArcGIS Web Adaptor for Java
5. Install patches for the ArcGIS Notebook Server and ArcGIS Web Adaptor for Java
6. Delete temporary files and uninstall Cinc Client

IDs of the images are saved in "vm-image-${var.deployment_id}-primary" 
and "vm-image-${var.deployment_id}-node" Key Vault secrets.

## Requirements

On the machine where Packer is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, and azure-mgmt-compute azure-storage-blob Azure Python  SDK packages must be installed 
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure CLI must be installed and configured
* Azure credentials must be configured using "az login" CLI command
* My Esri user name and password must be specified either using environment variables ARCGIS_ONLINE_USERNAME and ARCGIS_ONLINE_PASSWORD

## Key Vault Secrets

The template reads the following Key Vault secrets:

| Key Vault secret name | Description |
|-----------------------|-------------|
| chef-client-url-${var.os} | Chef Client URL |
| cookbooks-url | Chef Cookbooks for ArcGIS archive URL |
| storage-account-name | Private repository storage account name |
| vm-identity-client-id | Managed identity client Id |
| vm-identity-id | Managed identity resource Id |
| vm-image-${var.os} | Source VM Image Id |

The template writes the following Key Vault secrets:

| Key Vault secret name | Description |
|-----------------------|-------------|
| vm-image-${var.deployment_id}-primary | Built image Id for primary node |
| vm-image-${var.deployment_id}-node | Built image Id for additional nodes |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_notebook_server_patches | File names of ArcGIS Notebook Server patches to install | `string` | `[]` | no |
| arcgis_version | ArcGIS Notebook Server version | `string` | `"12.0"` | no |
| arcgis_web_adaptor_patches | File names of ArcGIS Web Adaptor patches to install | `string` | `[]` | no |
| azure_cli_version | Version of Azure CLI to install on the image | `string` | `"2.76.0"` | no |
| azure_region | Azure region display name | `string` | `env("AZURE_DEFAULT_REGION")` | no |
| deployment_id | Deployment Id | `string` | `"notebook-server-linux"` | no |
| docker_version | Version of Docker CE to install on the image | `string` | `"28.5.2"` | no |
| gpu_ready | If true, the image is built with GPU support | `bool` | `false` | no |
| license_level | ArcGIS Notebook Server license level | `string` | `"standard"` | no |
| notebook_server_web_context | ArcGIS Notebook Server web context | `string` | `"notebooks"` | no |
| os | Operating system Id (rhel9\|ubuntu24) | `string` | `"rhel9"` | no |
| os_disk_size | OS disk size in GB | `number` | `128` | no |
| run_as_user | User account used to run ArcGIS Notebook Server | `string` | `"arcgis"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis"` | no |
| skip_create_image | If true, Packer will not create the image | `bool` | `false` | no |
| vault_name | Name of the Azure Key Vault | `string` | n/a | yes |
| vm_size | Size of the source VM used to build the image | `string` | `"Standard_D8s_v5"` | no |
