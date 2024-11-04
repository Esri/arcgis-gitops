<!-- BEGIN_TF_DOCS -->
# Terraform module container-registry

The module creates and configures Azure Container Registry for AKS cluster:

1. Creates Azure Container Registry.
2. Configures pull-through cache to pull images from Docker Hub.
   See https://learn.microsoft.com/en-us/azure/container-registry/container-registry-artifact-cache
3. Assigns AcrPull role to the AKS cluster identity.
4. Creates Azure Private Endpoint for the container registry.
   See https://learn.microsoft.com/en-us/azure/container-registry/container-registry-private-link

## Requirements

Azure CLI must be installed on the machine where terraform is executed.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| null | n/a |
| random | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_container_registry.cluster_acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_container_registry_cache_rule.pull_through_cache](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry_cache_rule) | resource |
| [azurerm_key_vault_secret.acr_login_server](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.acr_name](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.cr_password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.cr_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_private_dns_zone.acr_private_dns_zone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.acr_private_dns_zone_virtual_network_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.acr_private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [null_resource.credential_set](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.container_registry_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [azurerm_key_vault.site_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| azure_region | Azure region display name | `string` | n/a | yes |
| container_registry_password | Source container registry user password | `string` | n/a | yes |
| container_registry_url | Source container registry URL | `string` | n/a | yes |
| container_registry_user | Source container registry user name | `string` | n/a | yes |
| principal_id | AKS cluster service principal Id | `string` | n/a | yes |
| resource_group_name | AKS cluster resource group name | `string` | n/a | yes |
| site_id | ArcGIS Enterprise site Id | `string` | n/a | yes |
| subnet_id | ACR private endpoint subnet Id | `string` | n/a | yes |
| vnet_id | ACR private endpoint DNS zone VNet Id | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| acr_login_server | Private container registry login server |
<!-- END_TF_DOCS -->