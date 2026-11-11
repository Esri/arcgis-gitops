# Terraform module lv_extend

Terraform module lv_extend extends the logical volume on Azure VMs in a deployment.

The module uses az_run_shell_script python module to run ${var.os}.sh scripts on the deployment's VMs in specific roles.

For RHEL 9, the script discovers the root LVM logical volume, its physical volume,
and the backing disk and partition instead of relying on device enumeration order.
It requires exactly one partition-backed physical volume in the root volume group
and stops before resizing if that layout cannot be verified. The application data
disk mounted at `/opt` is not resized. An already-grown partition is accepted only
when `growpart` reports `NOCHANGE`; logical volume extension is skipped when no
free extents remain. Review the Terraform plan and rerun the approved deployment
workflow to apply this change. Disk growth cannot be undone by shrinking; recovery
requires restoring a VM/disk backup or redeploying from the approved image.

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
| [null_resource.mount](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azurerm_key_vault.enterprise_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_resources.enterprise_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resources) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| machine_roles | List of machine roles | `list(string)` | n/a | yes |
| os | Operating system ID (rhel9\|ubuntu24) | `string` | `"rhel9"` | no |
