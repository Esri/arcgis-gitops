<!-- BEGIN_TF_DOCS -->
# Terraform module site_core_info

Terraform module site_core_info retrieves names and Ids of core Azure resources
created by infrastructure-core module from Azure Key Vault and
returns them as output values.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.app_gateway_subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.internal_subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.private_subnets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.storage_account_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.storage_account_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.vnet_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secrets.secrets](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secrets) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| app_gateway_subnets | Ids of app gateway subnets |
| internal_subnets | Ids of internal subnets |
| private_subnets | Ids of private subnets |
| storage_account_key | Azure storage account key |
| storage_account_name | Azure storage account name |
| vault_id | Azure Key Vault Id |
| vault_name | Azure Key Vault Name |
| vault_uri | Azure Key Vault URI |
| vnet_id | VNet Id of ArcGIS Enterprise site |
<!-- END_TF_DOCS -->