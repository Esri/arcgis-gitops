<!-- BEGIN_TF_DOCS -->
# Terraform module bootstrap

Terraform module installs or upgrades Chef client and Chef Cookbooks for ArcGIS on Azure VMs.

The module uses az_bootstrap.py script to run managed Run Command on the deployment's Azure VMs in the specific roles.

## Requirements

On the machine where Terraform is executed:

* Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.bootstrap](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azurerm_key_vault.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.chef_client_url](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_key_vault_secret.cookbooks_url](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_resources.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resources) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| chef_client_url | URL of Chef client installer | `string` | `null` | no |
| chef_cookbooks_url | URL of ArcGIS Chef cookbooks archive | `string` | `null` | no |
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| os | Operating system id | `string` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->