<!-- BEGIN_TF_DOCS -->
# Terraform module clean_up

Terraform module deletes files in specific directories on deployment VMs in specific roles.
Optionally, if the uninstall_chef_client variable is set to true, the module also uninstalls Chef client on the instances.

The module uses az_clean_up.py script to run {var.site-id}-clean-up Azure Run Command on the deployment's VMs in specific roles.

## Requirements

On the machine where Terraform is executed:

* Python 3.9 or later with [Azure SDK for Python](https://docs.microsoft.com/en-us/python/api/overview/azure/?view=azure-python) packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* Azure credentials must be configured

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |
| null | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.clean_up](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azurerm_key_vault.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_resources.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resources) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment Id | `string` | n/a | yes |
| directories | List of directories to clean up | `list(string)` | `[]` | no |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
| uninstall_chef_client | Set to true to uninstall Chef/Cinc Client | `bool` | `true` | no |
<!-- END_TF_DOCS -->