<!-- BEGIN_TF_DOCS -->
# Terraform Module K8s-cluster

The Terraform module provisions Azure Kubernetes Service (AKS) cluster
that meets [ArcGIS Enterprise on Kubernetes system requirements](https://enterprise-k8s.arcgis.com/en/latest/deploy/deploy-a-cluster-in-azure-kubernetes-service.htm).

![Azure Kubernetes Service (AKS) cluster](k8s-cluster.png "Azure Kubernetes Service (AKS) cluster")

The module creates a resource group with the following Azure resouces:

* AKS cluster with default node pool in the private subnet 1
* ALB Controller and Application Gateway for Containers associated with app gateway subnet 1.
* Container registry with private endpoint in internal subnet 1, private DNS zone, and cache rules to pull images from Docker Hub container registry.
* Monitoring subsystem that include Azure Monitor workspace and Azure Managed Grafana instances.

Once the AKS cluster is available, the module creates storage classes for Azure Disk CSI driver.

## Requirements

The subnets and virtual network Ids are retrieved from Azure Key Vault secrets. The key vault, subnets, and other
network infrastructure resources must be created by the [infrastructure-core](../infrastructure-core) module.

Azure providers Microsoft.Monitor, Microsoft.Dashboard, Microsoft.NetworkFunction, and Microsoft.ServiceNetworking
must be registered in the subscription.

On the machine where Terraform is executed:

* Azure subscription Id must be specified by ARM_SUBSCRIPTION_ID environment variable.
* Azure service principal credentials must be configured by ARM_CLIENT_ID, ARM_TENANT_ID, and ARM_CLIENT_SECRET environment variables.
* Azure CLI, Helm and kubectl must be installed.

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 4.16 |
| null | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| alb_controller | ./modules/alb-controller | n/a |
| container_registry | ./modules/container-registry | n/a |
| monitoring | ./modules/monitoring | n/a |
| site_core_info | ../../modules/site_core_info | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault_secret.aks_identity_client_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.aks_identity_principal_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.alb_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_kubernetes_cluster.site_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_resource_group.cluster_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.storage_blob_data_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [null_resource.storage_class](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.update_kubeconfig](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| azure_region | Azure region display name | `string` | n/a | yes |
| container_registry_password | Source container registry user password | `string` | `null` | no |
| container_registry_url | Source container registry URL | `string` | `"docker.io"` | no |
| container_registry_user | Source container registry user name | `string` | `null` | no |
| default_node_pool | <p>Default AKS node pool configuration properties:</p>   <ul>   <li>name - The name which should be used for the default Kubernetes Node Pool</li>   <li>vm_size - The size of the Virtual Machine</li>   <li>os_disk_size_gb - The size of the OS Disk which should be used for each agent in the Node Pool</li>   <li>node_count - The initial number of nodes which should exist in this Node Pool</li>   <li>max_count - The maximum number of nodes which should exist in this Node Pool</li>   <li>min_count - The minimum number of nodes which should exist in this Node Pool</li>   </ul> | ```object({ name = string vm_size = string os_disk_size_gb = number node_count = number max_count = number min_count = number })``` | ```{ "max_count": 8, "min_count": 4, "name": "default", "node_count": 4, "os_disk_size_gb": 1024, "vm_size": "Standard_D8s_v5" }``` | no |
| site_id | ArcGIS Enterprise site Id | `string` | `"arcgis"` | no |
| subnet_id | AKS cluster subnet ID | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| acr_login_server | Private container registry login server |
| alb_id | The ID of the Azure Application Load Balancer |
| cluster_name | AKS cluster name |
| cluster_resource_group | AKS cluster resource group |
| grafana_endpoint | Grafana endpoint |
| prometheus_query_endpoint | Prometheus query endpoint |
| subscription_id | Azure subscription Id |
<!-- END_TF_DOCS -->