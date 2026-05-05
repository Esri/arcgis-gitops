<!-- BEGIN_TF_DOCS -->
# Terraform module enterprise_core_info

Terraform module enterprise_core_info retrieves names and Ids of core Azure resources
created by infrastructure-core module from Azure Key Vault and
returns them as output values.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault.enterprise_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.storage_account_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.storage_account_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.vnet_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_resources.enterprise_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resources) | data source |
| [azurerm_storage_account.enterprise_storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| app_gateway_subnets | IDs of app gateway subnets |
| internal_subnets | IDs of internal subnets |
| private_subnets | IDs of private subnets |
| resource_group_name | Resource Group Name |
| storage_account_blob_endpoint | Azure storage account primary blob endpoint |
| storage_account_id | Azure storage account ID |
| storage_account_key | Azure storage account key |
| storage_account_name | Azure storage account name |
| vault_id | Azure Key Vault ID |
| vault_name | Azure Key Vault Name |
| vault_uri | Azure Key Vault URI |
| vnet_id | VNet ID of ArcGIS Enterprise |
<!-- END_TF_DOCS -->