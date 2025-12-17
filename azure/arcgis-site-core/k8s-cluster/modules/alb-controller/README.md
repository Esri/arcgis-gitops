<!-- BEGIN_TF_DOCS -->
# Terraform module alb-controller

The module deploys Application Gateway for Containers ALB Controller to AKS cluster:

1. Creates a user managed identity for ALB controller and federates the identity as Workload Identity to use in the AKS cluster.
2. Assigns required roles to the identity.
2. Installs ALB Controller using Helm.
3. Creates an Application Gateway for Containers and associates it with a subnet.

See: https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/quickstart-deploy-application-gateway-for-containers-alb-controller

## Requirements

Helm must be installed on the machine where terraform is executed.

## Providers

| Name | Version |
|------|---------|
| azurerm | n/a |
| null | n/a |
| time | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_application_load_balancer.alb](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_load_balancer) | resource |
| [azurerm_application_load_balancer_subnet_association.alb](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_load_balancer_subnet_association) | resource |
| [azurerm_federated_identity_credential.azure_alb_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_role_assignment.aks_cluster_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.appgw_configuration_manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.network_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.azure_alb_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [null_resource.helm_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [time_sleep.wait_60_seconds](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azurerm_kubernetes_cluster.site_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_cluster) | data source |
| [azurerm_resource_group.cluster_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alb_subnet_id | Subnet Id for the ALB | `string` | n/a | yes |
| azure_region | Azure region display name | `string` | n/a | yes |
| cluster_name | Name of the AKS cluster | `string` | n/a | yes |
| controller_version | Version of the ALB Controller | `string` | `"1.8.12"` | no |
| resource_group_name | AKS cluster resource group name | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| alb_id | The ID of the Azure Application Load Balancer |
<!-- END_TF_DOCS -->