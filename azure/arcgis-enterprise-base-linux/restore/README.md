<!-- BEGIN_TF_DOCS -->
# Restore Terraform Module for Base ArcGIS Enterprise on Linux

The Terraform module restores a base ArcGIS Enterprise deployment on Linux from backup.

The module runs the WebGISDR utility with 'import' option on the primary VM of the deployment.

The backup is retrieved from the "webgisdr-backups" and "content-backups" blob containers in the storage
account of the enterprise specified by "backup_enterprise_id" input variable.

## Requirements

The base ArcGIS Enterprise must be configured on the deployment by application terraform module for base ArcGIS Enterprise on Linux.

On the machine where Terraform is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured using "az login" CLI command

The deployment VMs must have access to the storage account of the backup enterprise specified by the `backup_enterprise_id` input variable,
so that WebGISDR import can retrieve backups from the `webgisdr-backups` and `content-backups` containers:

* The deployment VMs must have network-level access to the storage account endpoint of the backup enterprise.
* The user-assigned managed identity attached to the deployment virtual machines must have read access
  to the storage account of the backup enterprise.

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.46 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| arcgis_enterprise_webgisdr_import | ../../modules/run_chef | n/a |
| backup_enterprise_core_info | ../../modules/enterprise_core_info | n/a |
| target_enterprise_core_info | ../../modules/enterprise_core_info | n/a |

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
| backup_enterprise_id | ArcGIS Enterprise ID of the backup to restore from | `string` | `"arcgis"` | no |
| backup_restore_mode | Restore mode: specifies the type of backup to restore (backup, full, incremental) | `string` | `"backup"` | no |
| deployment_id | Deployment ID | `string` | `"enterprise-base-linux"` | no |
| enterprise_id | ArcGIS Enterprise ID | `string` | `"arcgis"` | no |
| execution_timeout | Execution timeout in seconds | `number` | `36000` | no |
| portal_admin_url | Portal for ArcGIS administrative URL | `string` | `"https://localhost:7443/arcgis"` | no |
| run_as_user | User name for the account used to run Portal for ArcGIS | `string` | `"arcgis"` | no |
<!-- END_TF_DOCS -->