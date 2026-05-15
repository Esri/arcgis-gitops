<!-- BEGIN_TF_DOCS -->
# Terraform module aznfs_fileserver

Terraform module creates or references an NFS file share for the deployment's file server.

If `fileserver_deployment_id` variable is null, the module creates a new storage account and an NFS file share.

If `fileserver_deployment_id` variable is not null, the module reads the NFS file share network path from Key Vault secrets for the specified deployment.

## Requirements

On the machine where Terraform is executed:

* Azure credentials must be configured using "az login" CLI command

## Key Vault Secrets

### Secrets Read by the Module

| Secret Name                             | Description |
|-----------------------------------------|-------------|
| ${var.fileserver_deployment_id}-aznfs-network-path | Network path for the NFS file share (if ${var.fileserver_deployment_id} is not null) |

### Secrets Written by the Module

| Secret Name                               | Description |
|-------------------------------------------|-------------|
| ${var.deployment_id}-aznfs-network-path   | Network path for the NFS file share (if ${var.fileserver_deployment_id} is null) |

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault_secret.aznfs_network_path](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_private_endpoint.file_store_pe](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_storage_account.file_store](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_share.fileserver](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) | resource |
| [azurerm_key_vault_secret.aznfs_network_path](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_private_dns_zone.privatelink_file](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/private_dns_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| deployment_id | ArcGIS Enterprise deployment ID | `string` | n/a | yes |
| enterprise_id | ArcGIS Enterprise ID | `string` | n/a | yes |
| fileserver_deployment_id | Use the EFS filesystem from the deployment with the given ID. If not specified, a dedicated EFS filesystem will be created for this deployment. | `string` | `null` | no |
| fileserver_size | Maximum size of the NFS file share in GB | `number` | `1024` | no |
| key_vault_id | ID of the Key Vault | `string` | n/a | yes |
| location | Azure region where the file server resources will be created or are located (if fileserver_deployment_id is specified). | `string` | n/a | yes |
| resource_group_name | Name of the resource group where the file server resources will be created or are located (if fileserver_deployment_id is specified). | `string` | n/a | yes |
| storage_replication_type | The replication type of the storage accounts. Possible values are: LRS (Locally-redundant storage), ZRS (Zone-redundant storage). | `string` | `"ZRS"` | no |
| subnet_id | EFS target subnet ID. | `string` | n/a | yes |
| unique_name_suffix | A unique suffix to append to the names of created resources to avoid naming conflicts. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| aznfs_network_path | The network path to access the NFS file share, stored as a secret in Key Vault. |
| storage_account_id | The ID of the storage account associated with the NFS file share. |
<!-- END_TF_DOCS -->