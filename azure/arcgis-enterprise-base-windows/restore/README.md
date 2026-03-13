<!-- BEGIN_TF_DOCS -->
# Restore Terraform Module for Base ArcGIS Enterprise on Windows

The Terraform module restores a base ArcGIS Enterprise deployment on Windows from backup.

The module runs the WebGISDR utility with 'import' option on the primary VM of the deployment.

The backup is retrieved from the "webgisdr-backups" and "content-backups" blob containers in the storage
account of the site specified by "backup_site_id" input variable.

## Requirements

The base ArcGIS Enterprise must be configured on the deployment by application terraform module for base ArcGIS Enterprise on Windows.

The user assigned managed identity assigned to the VMs must have Storage Blob Data Owner role on
the backup site's storage account.
On the machine where Terraform is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured using "az login" CLI command

The deployment VMs must have access to the storage account of the backup site specified by the `backup_site_id` input variable,
so that WebGISDR import can retrieve backups from the `webgisdr-backups` and `content-backups` containers:

* The deployment VMs must have network-level access to the storage account endpoint of the backup site.
* The user-assigned managed identity attached to the deployment virtual machines must have read access
  to the storage account of the backup site.

## Key Vault Secrets

The module reads the following Key Vault secrets:

| Key Vault secret name | Description |
|-----------------------|-------------|
| storage-account-key | Site's storage account key |
| storage-account-name | Site's storage account name |
| subnets | VNet subnets IDs |
| vm-identity-client-id | Client ID of the user-assigned VM identity |
| vnet-id | VNet ID |

> The storage-account-name, storage-account-key, subnets, and vnet-id
  secrets are retrieved by backup_site_core_info module.

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.46 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| arcgis_enterprise_webgisdr_import | ../../modules/run_chef | n/a |
| backup_site_core_info | ../../modules/site_core_info | n/a |
| target_site_core_info | ../../modules/site_core_info | n/a |

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
| backup_restore_mode | Restore mode: specifies the type of backup to restore (backup, full, incremental) | `string` | `"backup"` | no |
| backup_site_id | ArcGIS site Id of the backup to restore from | `string` | `"arcgis"` | no |
| deployment_id | Deployment Id | `string` | `"enterprise-base-windows"` | no |
| execution_timeout | Execution timeout in seconds | `number` | `36000` | no |
| portal_admin_url | Portal for ArcGIS administrative URL | `string` | `"https://localhost:7443/arcgis"` | no |
| run_as_password | Password for the account used to run Portal for ArcGIS | `string` | n/a | yes |
| run_as_user | User name for the account used to run Portal for ArcGIS | `string` | `"arcgis"` | no |
| site_id | ArcGIS site Id | `string` | `"arcgis"` | no |
<!-- END_TF_DOCS -->