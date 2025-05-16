# Core Azure Resources for ArcGIS Enterprise Site

This template provides workflows for provisioning:

* Networking and storage Azure resource shared across multiple deployments of an ArcGIS Enterprise site,
* Azure Kubernetes Service (AKS) cluster that meets ArcGIS Enterprise on Kubernetes system requirements.

Before running the template workflows, configure the GitHub repository settings as described in the general [Instructions](../README.md#instructions) section.

To enable the template's workflows, copy the .yaml files from the template's `workflows` directory to `/.github/workflows` directory in the `main` branch, commit the changes, and push the branch to GitHub.

> To prevent accidental destruction of the resources, don't enable *-destroy workflows until it is necessary.

> Refer to READMEs of the Terraform modules for descriptions of specific configuration properties.

## Create Core Azure Resources

GitHub Actions workflow **site-core-azure** creates core Azure resources for an ArcGIS Enterprise site.

The workflow uses [infrastructure-core](infrastructure-core/README.md) Terraform module with [infrastructure-core.tfvars.json](../../config/azure/arcgis-site-core/infrastructure-core.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. (Optional) Update CIDR blocks of the subnets to match the required network topology.
2. Commit the changes to the `main` branch and push the branch to GitHub.
3. Run site-core-azure workflow using the `main` branch.

## Deploy K8s Cluster

GitHub Actions workflow **site-k8s-cluster-azure** deploys Azure AKS cluster that meets the ArcGIS Enterprise on Kubernetes system requirements.

The workflow uses [k8s-cluster](k8s-cluster/README.md) Terraform module with [k8s-cluster.tfvars.json](../../config/azure/arcgis-site-core/k8s-cluster.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. (Optional) Set "default_node_pool" properties to the required node pool configuration.
2. (Optional) Set "subnet_id" property to the subnet Id from the site's VNet. By default, the first private subnet is used.
3. Commit the changes to the `main` branch and push the branch to GitHub.
4. Run site-k8s-cluster-azure workflow using the `main` branch.

## Destroy K8s Cluster

GitHub Actions workflow **site-k8s-cluster-azure-destroy** destroys the AKS cluster and other Azure resource created by site-k8s-cluster-azure workflow.

The workflow uses [k8s-cluster](k8s-cluster/README.md) Terraform module with [k8s-cluster.tfvars.json](../../config/azure/arcgis-site-core/k8s-cluster.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. Run site-k8s-cluster-azure-destroy workflow using the `main` branch.

## Destroy Core Azure Resources

GitHub Actions workflow **site-core-azure-destroy** destroys the Azure resources created by site-core-azure workflow.

The workflow uses [infrastructure-core](infrastructure-core/README.md) Terraform module with [infrastructure-core.tfvars.json](../../config/azure/arcgis-site-core/infrastructure-core.tfvars.json) config file.

Required service principal roles:

* Owner role at the subscription scope

Instructions:

1. Run site-core-azure-destroy workflow using the `main` branch.

> Along with all other resources, site-core-azure-destroy workflow destroys backups of all deployments.
