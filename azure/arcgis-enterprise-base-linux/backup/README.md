<!-- BEGIN_TF_DOCS -->
# Backup Terraform Module for Base ArcGIS Enterprise on Linux

The Terraform module creates a backup of base ArcGIS Enterprise deployment on Linux platform.

The module runs WebGISDR utility with 'export' option on the primary VM of the deployment.

The WebGISDR backups are stored in "webgisdr-backups" blob container of the site's Azure Storage account.
The Portal for ArcGIS content store backups are stored in "content-backups" blob container.

## Requirements

The base ArcGIS Enterprise must be configured on the deployment by application terraform module
for base ArcGIS Enterprise on Linux.

On the machine where Terraform is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, and azure-mgmt-compute azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured using "az login" CLI command

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.46 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| arcgis_enterprise_webgisdr_export | ../../modules/run_chef | n/a |
| site_core_info | ../../modules/site_core_info | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault_secret.vm_identity_client_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| admin_password | Portal for ArcGIS administrator user password | `string` | n/a | yes |
| admin_username | Portal for ArcGIS administrator user name | `string` | `"siteadmin"` | no |
| azure_region | Azure region display name | `string` | n/a | yes |
| backup_restore_mode | Type of backup | `string` | `"backup"` | no |
| deployment_id | Deployment Id | `string` | `"enterprise-base-linux"` | no |
| execution_timeout | Execution timeout in seconds | `number` | `36000` | no |
| portal_admin_url | Portal for ArcGIS administrative URL | `string` | `"https://localhost:7443/arcgis"` | no |
| run_as_user | User name for the account used to run Portal for ArcGIS | `string` | `"arcgis"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis"` | no |
<!-- END_TF_DOCS -->