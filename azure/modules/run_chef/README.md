<!-- BEGIN_TF_DOCS -->
# Terraform module run_chef

Terraform module run_chef runs Cinc client in zero mode on Azure VMs in specified roles.

The module runs az_run_chef.py python script that creates a Key Vault secret with Chef JSON attributes and
runs Azure Managed command on the deployment's Azure VMs in specific roles.

## Requirements

On the machine where Terraform is executed:

* Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/azure/?view=azure-python) package must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured

 Cinc client and Chef Cookbooks for ArcGIS must be installed on the target Azure VMs.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.run_chef](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azurerm_key_vault.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_resources.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resources) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| execution_timeout | Chef run timeout in seconds | `number` | `3600` | no |
| json_attributes | Chef run attributes in JSON format | `string` | n/a | yes |
| json_attributes_secret | Key Vault secret name of role attributes | `string` | n/a | yes |
| machine_roles | List of machine roles. | `list(string)` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
<!-- END_TF_DOCS -->