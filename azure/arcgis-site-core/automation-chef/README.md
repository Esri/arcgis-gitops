<!-- BEGIN_TF_DOCS -->
# Terraform module automation-chef

The module copies the distribution archive Chef/Cinc client setups and Chef cookbooks for ArcGIS  from the URLs specified
in [automation-chef-files.json](manifests/automation-chef-files.json) file to the private repository blob container.

The blob URLs are stored in the site's Key Vault secrets:

| Key Vault secret name | Description |
| --- | --- |
| chef-client-url-${os} | Blob URLs of Cinc Client setup for the operating systems |
| cookbooks-url | Blob URL of Chef cookbooks for ArcGIS distribution archive |

## Requirements

On the machine where Terraform is executed:

* Python 3.9 or later must be installed
* azure-identity, azure-keyvault-secrets, azure-mgmt-compute, and azure-storage-blob Azure Python SDK packages must be installed
* Path to azure/scripts directory must be added to PYTHONPATH
* The working directory must be set to the automation-chef module path (because [automation-chef-files.json](manifests/automation-chef-files.json) uses relative path to the Chef cookbooks archive)
* Azure credentials must be configured by "az login" Azure CLI command or environment variables.

Before using the module, the repository blob container must be created by infrastructure-core terraform module.

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.16 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| az_copy_files | ../../modules/az_copy_files | n/a |
| site_core_info | ../../modules/site_core_info | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault_secret.arcgis_cookbooks_url](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.chef_client_log_level](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.chef_client_urls](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| arcgis_cookbooks_path | S3 repository key of Chef cookbooks for ArcGIS distribution archive in the repository bucket | `string` | `"cookbooks/arcgis-5.2.0-cookbooks.tar.gz"` | no |
| azure_region | Azure region display name | `string` | n/a | yes |
| chef_client_paths | Chef/CINC Client setup blob names by operating system | `map(any)` | ```{ "rhel9": { "description": "Chef Client setup blob name for Red Hat Enterprise Linux version 9", "path": "cinc/cinc-18.7.6-1.el9.x86_64.rpm" }, "ubuntu24": { "description": "Chef Client setup blob name for Ubuntu 24.04 LTS", "path": "cinc/cinc_18.7.6-1.ubuntu24.amd64.deb" }, "windows2022": { "description": "Chef Client setup blob name for Microsoft Windows Server 2022", "path": "cinc/cinc-18.7.6-1-x64.msi" }, "windows2025": { "description": "Chef Client setup blob name for Microsoft Windows Server 2025", "path": "cinc/cinc-18.7.6-1-x64.msi" } }``` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |
<!-- END_TF_DOCS -->