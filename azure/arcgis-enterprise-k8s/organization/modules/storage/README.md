<!-- BEGIN_TF_DOCS -->
# Terraform module storage

The module:

* Creates an Azure resource group for the organization's stores,
* Creates an Azure storage account and a blob container for the organization's object store,
* Grants the specified principal Storage Blob Data Contributor role in the storage accounts, and
* Creates cloud config JSON file for the object store.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| local | n/a |
| random | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_resource_group.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.storage_blob_data_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.deployment_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.object_store](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [local_sensitive_file.cloud_config_json_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/sensitive_file) | resource |
| [random_id.storage_account_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| azure_region | Azure region display name | `string` | n/a | yes |
| client_id | Client Id of the AKS cluster identity | `string` | n/a | yes |
| cloud_config_json_file_path | ArcGIS Enterprise on Kubernetes cloud configuration JSON file path | `string` | `null` | no |
| deployment_id | ArcGIS Enterprise deployment Id | `string` | `"arcgis-enterprise-k8s"` | no |
| principal_id | Principal Id of the AKS cluster identity | `string` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis-enterprise"` | no |

## Outputs

| Name | Description |
|------|-------------|
| blob_container_name | Azure blob container name |
| resource_group_name | Azure resource group name |
| storage_account_name | Azure storage account name |
<!-- END_TF_DOCS -->