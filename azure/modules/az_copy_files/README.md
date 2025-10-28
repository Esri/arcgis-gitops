<!-- BEGIN_TF_DOCS -->
# Terraform module az_copy_files

Terraform module az_copy_files copies files from local file system, public URLs, and, My Esri, and ArcGIS patch repositories to Azure Blob Storage.

The module uses az_copy_files.py script to copy files defined in a JSON index file to an Azure Blob Storage container.

## Requirements

On the machine where Terraform is executed:

* Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured

## Providers

| Name | Version |
|------|---------|
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.az_copy_files](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| container_name | Azure Storage blob container name | `string` | `"repository"` | no |
| index_file | Index file local path | `string` | n/a | yes |
| storage_account_blob_endpoint | Azure Storage account blob endpoint | `string` | n/a | yes |
<!-- END_TF_DOCS -->